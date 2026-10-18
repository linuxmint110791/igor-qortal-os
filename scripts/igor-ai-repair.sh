#!/usr/bin/env bash
# Igor-Qortal OS installer diagnostics and guarded repair helper.
# Safe by default: diagnoses first; never runs AI-generated commands.
set -Eeuo pipefail

VERSION="1.0.0"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/igor-qortal-os"
LOG_FILE="$LOG_DIR/installer-repair.log"
mkdir -p "$LOG_DIR"
chmod 700 "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

say() { printf '[Igor-Qortal Repair] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

say "Diagnostika v$VERSION käivitus: $(date -Is 2>/dev/null || date)"
say "OS: $(. /etc/os-release 2>/dev/null; printf '%s %s' "${PRETTY_NAME:-unknown}" "${VERSION_CODENAME:-}")"
say "Kernel: $(uname -sr)"
say "Logi: $LOG_FILE"

ISSUES=0
REPORT="$LOG_DIR/installer-diagnostic.txt"
{
  echo "Igor-Qortal OS installer diagnostic"
  echo "Date: $(date -Is 2>/dev/null || date)"
  echo "Host: $(hostname 2>/dev/null || echo unknown)"
  echo "Kernel: $(uname -sr)"
  if [[ -r /etc/os-release ]]; then cat /etc/os-release; fi
  echo
  echo "Disk space:"
  df -h / /tmp 2>&1 || true
  echo
  echo "APT source files:"
  grep -RnhE '^(deb |URIs:|Suites:|Types:|Enabled:)' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true
  echo
  echo "Last dpkg status:"
  dpkg --audit 2>&1 || true
} > "$REPORT"
chmod 600 "$REPORT"

if [[ $EUID -eq 0 ]]; then
  say "Töötab root-õigustes."
else
  say "Töötab tavakasutajana; süsteemi muutvad parandused vajavad sudo õigust."
fi

if ! have apt-get || ! have dpkg; then
  warn "APT/dpkg puudub. See skript on mõeldud Debianil põhinevale süsteemile."
  ISSUES=$((ISSUES + 1))
fi

if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  if [[ "${ID:-}" != "debian" && " ${ID_LIKE:-} " != *" debian "* ]]; then
    warn "Tuvastatud süsteem pole Debian; paketiparandusi ei tehta automaatselt."
    ISSUES=$((ISSUES + 1))
  fi
fi

if have df; then
  avail_kb=$(df -Pk / 2>/dev/null | awk 'NR==2 {print $4+0}')
  if [[ -n "${avail_kb:-}" && "$avail_kb" -lt 2097152 ]]; then
    warn "Root-failisüsteemis on alla 2 GiB vaba ruumi. ISO ehitamine/paigaldamine võib ebaõnnestuda."
    ISSUES=$((ISSUES + 1))
  fi
fi

if [[ -r /etc/apt/sources.list ]] && grep -qE '^[[:space:]]*deb[[:space:]]+cdrom:' /etc/apt/sources.list; then
  warn "Leiti cdrom: APT allikas. Kui paigaldus-ISO pole saadaval, võib apt update selle taha takerduda."
  say "Ohutu juhis: ava /etc/apt/sources.list ja kommenteeri ainult cdrom: rida; ära eemalda teisi allikaid."
  ISSUES=$((ISSUES + 1))
fi

if have dpkg; then
  audit=$(dpkg --audit 2>&1 || true)
  if [[ -n "$audit" ]]; then
    warn "dpkg teatab pooleli või vigastest pakettidest:"
    printf '%s\n' "$audit"
    ISSUES=$((ISSUES + 1))
  fi
fi

if have getent && ! getent hosts deb.debian.org >/dev/null 2>&1; then
  warn "DNS ei lahenda deb.debian.org; kontrolli võrguühendust/DNS-i."
  ISSUES=$((ISSUES + 1))
fi

say "Diagnostika valmis. Leitud probleemide arv: $ISSUES"
say "Täielik aruanne: $REPORT"

# Optional AI advisor. Explicit opt-in only; logs/system details are sent to
# the configured endpoint only when IGOR_AI_DIAGNOSE=1 and a key is supplied.
# AI output is advice only and is never executed as shell commands.
if [[ "${IGOR_AI_DIAGNOSE:-0}" == "1" ]]; then
  if [[ -z "${OPENAI_API_KEY:-}" ]]; then
    warn "AI analüüs valiti, kuid OPENAI_API_KEY puudub. Kohalik diagnostika toimis ikkagi."
  elif ! have curl || ! have python3; then
    warn "AI analüüs vajab curl-i ja python3; kohalik diagnostika toimis ikkagi."
  else
    endpoint="${OPENAI_BASE_URL:-https://api.openai.com/v1}/chat/completions"
    model="${OPENAI_MODEL:-gpt-4.1-mini}"
    say "Saadan diagnostikaaruande valitud AI-teenusele: $endpoint (mudel $model)"
    payload=$(python3 - "$model" "$REPORT" <<'PY'
import json, pathlib, sys
model, report = sys.argv[1], pathlib.Path(sys.argv[2]).read_text(errors="replace")
print(json.dumps({
  "model": model,
  "messages": [
    {"role":"system","content":"You are a Linux installer troubleshooting assistant. Analyze the supplied Debian diagnostic report. Explain likely causes and provide cautious, reversible commands. Never suggest deleting user data, disabling signature checks, or executing downloaded scripts. Do not claim to have changed the system."},
    {"role":"user","content":"Diagnose this Igor-Qortal OS installer report. Give prioritized findings and safe next steps. Do not output an executable script.\n\n"+report}
  ],
  "temperature": 0.2
}))
PY
)
    if response=$(curl --fail --silent --show-error --max-time 45 \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -H 'Content-Type: application/json' \
      --data "$payload" "$endpoint"); then
      python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["choices"][0]["message"]["content"])' <<< "$response" \
        | tee "$LOG_DIR/ai-advice.txt"
      chmod 600 "$LOG_DIR/ai-advice.txt"
    else
      warn "AI päring ebaõnnestus. Kohalik diagnostika on alles; kontrolli API aadressi/võrku."
    fi
  fi
else
  say "AI pilveanalüüs on välja lülitatud. Soovi korral lülita see teadlikult sisse: IGOR_AI_DIAGNOSE=1."
fi

say "Ühtegi AI-st saadud käsku ei käivitatud ega süsteemset muudatust tehtud."
exit 0
