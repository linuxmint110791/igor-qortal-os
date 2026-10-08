#!/usr/bin/env bash
set -euo pipefail
FILE="igor-qortal-os-v2-with-logo-embedded.sh"
test -f "$FILE"

# Safe, deterministic repairs only. Never rewrite arbitrary code.
sed -i 's/^fiF$/fi/' "$FILE"
sed -i 's/^SCRIPT$/SCRIPT/' "$FILE"

# Keep the Reticulum menu numbering internally consistent if an older copy
# accidentally contains the obsolete sixth exit case.
python3 - <<'PY'
from pathlib import Path
p=Path("igor-qortal-os-v2-with-logo-embedded.sh")
s=p.read_text()
s=s.replace("      6) exit 0 ;;\n", "      5) exit 0 ;;\n")
p.write_text(s)
PY

bash -n "$FILE"
echo "ISO builder validation/repair: OK"
