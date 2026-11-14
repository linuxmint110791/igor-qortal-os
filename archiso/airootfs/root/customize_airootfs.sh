#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "customize_airootfs.sh failed at line $LINENO" >&2' ERR

echo igorcoin-qortal > /etc/hostname
id liveuser >/dev/null 2>&1 || useradd -m -G wheel,audio,video,storage,optical,network -s /bin/bash liveuser
install -d -m 0755 /etc/sudoers.d
printf '%s\n' 'liveuser ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/99-liveuser
chmod 0440 /etc/sudoers.d/99-liveuser
visudo -cf /etc/sudoers.d/99-liveuser

id qortal >/dev/null 2>&1 || useradd --system --create-home --home-dir /var/lib/qortal --shell /usr/bin/nologin qortal
id reticulum >/dev/null 2>&1 || useradd --system --create-home --home-dir /var/lib/reticulum --shell /usr/bin/nologin reticulum
install -d -o qortal -g qortal -m 0750 /opt/qortal/core /opt/qortal/hub /var/lib/qortal
install -d -o reticulum -g reticulum -m 0750 /var/lib/reticulum

# Qortal is optional and offered after the first desktop login.
install -d -m 0755 /usr/local/bin
cat > /usr/local/bin/igorcoin-qortal-setup <<'QORTAL_SETUP'
#!/usr/bin/env bash
set -Eeuo pipefail
zenity --question --title="IgorCoin-Qortal OS" --width=420 --text="Kas soovid paigaldada Qortal Core'i ja Qortal Hubi?\n\nVõid valida Ei ja paigaldada Qortali hiljem rakenduste menüüst." || exit 0
sudo -v
(
  set -Eeuo pipefail
  CORE_JSON="$(curl -fsSL https://api.github.com/repos/Qortal/qortal/releases/latest)"
  CORE_URL="$(jq -er '[.assets[] | select(.name | test("qortal.*\\.jar$"; "i"))][0].browser_download_url' <<<"$CORE_JSON")"
  HUB_JSON="$(curl -fsSL https://api.github.com/repos/Qortal/Qortal-Hub/releases/latest)"
  HUB_URL="$(jq -er '[.assets[] | select((.name | test("x86_64|x64|Qortal-Hub\\.AppImage$"; "i")) and (.name | endswith(".AppImage")))][0].browser_download_url' <<<"$HUB_JSON")"
  sudo install -d -o qortal -g qortal -m 0750 /opt/qortal/core /opt/qortal/hub
  curl -fL --retry 3 "$CORE_URL" -o /tmp/qortal.jar
  sudo install -o qortal -g qortal -m 0640 /tmp/qortal.jar /opt/qortal/core/qortal.jar
  curl -fL --retry 3 "$HUB_URL" -o /tmp/Qortal-Hub.AppImage
  sudo install -o root -g root -m 0755 /tmp/Qortal-Hub.AppImage /opt/qortal/hub/Qortal-Hub.AppImage
  sudo systemctl enable --now qortal.service
) 2>&1 | zenity --progress --title="Qortal installation" --text="Laadin ja seadistan Qortali..." --pulsate --auto-close
zenity --info --title="IgorCoin-Qortal OS" --text="Qortal Core ja Hub on paigaldatud. Core: https://127.0.0.1:12391"
QORTAL_SETUP
chmod 0755 /usr/local/bin/igorcoin-qortal-setup
cat > /usr/share/applications/igorcoin-qortal-setup.desktop <<'EOF'
[Desktop Entry]
Name=Install Qortal
Comment=Install Qortal Core and Qortal Hub when you choose
Exec=/usr/local/bin/igorcoin-qortal-setup
Icon=applications-internet
Terminal=false
Type=Application
Categories=Network;System;
EOF

install -d -m 0755 /opt/reticulum
python -m venv /opt/reticulum/venv
/opt/reticulum/venv/bin/pip install --no-cache-dir --upgrade pip wheel
/opt/reticulum/venv/bin/pip install --no-cache-dir rns nomadnet

cat > /usr/share/applications/reticulum-meshchat.desktop <<'EOF'
[Desktop Entry]
Name=Reticulum MeshChat
Comment=Mesh messaging over Reticulum
Exec=/opt/qortal/meshchat/ReticulumMeshChat.AppImage
Icon=applications-internet
Terminal=false
Type=Application
Categories=Network;Chat;
EOF

cat > /usr/share/applications/nomadnet.desktop <<'EOF'
[Desktop Entry]
Name=NomadNet
Comment=Reticulum mesh network terminal
Exec=/opt/reticulum/venv/bin/nomadnet
Icon=utilities-terminal
Terminal=true
Type=Application
Categories=Network;
EOF

# Qortal dark press-kit wallpaper and KDE feedback opt-out.
install -d -m 0755 /usr/share/wallpapers/IgorCoin-Qortal
if curl -fL --retry 3 --retry-delay 2 'https://wiki.qortal.org/lib/exe/fetch.php?media=qortal_background_extra_dark_.jpg' -o /usr/share/wallpapers/IgorCoin-Qortal/wallpaper.jpg; then
  install -d -m 0755 /etc/skel/.config/autostart
  cat > /etc/skel/.config/autostart/igorcoin-wallpaper.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=IgorCoin-Qortal Wallpaper
Exec=plasma-apply-wallpaperimage /usr/share/wallpapers/IgorCoin-Qortal/wallpaper.jpg
X-KDE-autostart-after=panel
EOF
fi
install -d -m 0755 /etc/skel/.config
cat > /etc/skel/.config/kuserfeedbackrc <<'EOF'
[UserFeedback]
FeedbackLevel=0
EOF

install -d -o liveuser -g liveuser /home/liveuser/.config /home/liveuser/Desktop /home/liveuser/.config/autostart
printf '[General]\nColorScheme=BreezeDark\nName=IgorCoin-Qortal Dark\n' > /home/liveuser/.config/kdeglobals
chown liveuser:liveuser /home/liveuser/.config/kdeglobals
cp -a /etc/skel/.config/autostart/. /home/liveuser/.config/autostart/ 2>/dev/null || true
cp /etc/skel/.config/kuserfeedbackrc /home/liveuser/.config/kuserfeedbackrc
chown -R liveuser:liveuser /home/liveuser/.config

sed -i '/^\[igorcoin\]$/,/^$/d' /etc/pacman.conf || true
systemctl enable NetworkManager.service systemd-resolved.service sddm.service bluetooth.service reticulum.service
systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service

cat > /usr/share/applications/archinstall.desktop <<'EOF'
[Desktop Entry]
Name=Install IgorCoin-Qortal OS
Comment=Open the Archinstall guided installer
Exec=konsole -e archinstall
Icon=system-software-install
Terminal=false
Type=Application
Categories=System;
EOF
echo "Live image configuration completed."
