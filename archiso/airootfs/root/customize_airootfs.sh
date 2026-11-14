#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "customize_airootfs.sh failed at line $LINENO" >&2' ERR

LIVE_USER="igorcoin"

echo igorcoin-qortal > /etc/hostname
id "$LIVE_USER" >/dev/null 2>&1 || useradd -m -G wheel,audio,video,storage,optical,network -s /bin/bash "$LIVE_USER"
install -d -m 0755 /etc/sudoers.d
printf '%s\n' "$LIVE_USER ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-liveuser
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
  sudo tee /usr/share/applications/qortal-hub.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Qortal Hub
Comment=Qortal desktop interface
Exec=/opt/qortal/hub/Qortal-Hub.AppImage
Icon=applications-internet
Terminal=false
Type=Application
Categories=Network;
EOF
) 2>&1 | zenity --progress --title="Qortal installation" --text="Laadin ja seadistan Qortali..." --pulsate --auto-close
zenity --info --title="IgorCoin-Qortal OS" --text="Qortal Core ja Hub on paigaldatud. Core: https://127.0.0.1:12391"
QORTAL_SETUP
chmod 0755 /usr/local/bin/igorcoin-qortal-setup
install -d -m 0755 /etc/skel/.config/autostart
cat > /etc/skel/.config/autostart/igorcoin-qortal-choice.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=IgorCoin Qortal Setup
Exec=/usr/local/bin/igorcoin-qortal-setup
X-GNOME-Autostart-enabled=true
EOF
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

cat > /usr/local/bin/igorcoin-qortal-official-install <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || {
  echo "Install curl or wget first." >&2
  exit 1
}
bash <(curl -fsSL https://link.qortal.dev/linux-script || wget -qO- https://link.qortal.dev/linux-script)
EOF
chmod 0755 /usr/local/bin/igorcoin-qortal-official-install
cat > /usr/share/applications/igorcoin-qortal-official-install.desktop <<'EOF'
[Desktop Entry]
Name=Qortal Universal Linux Installer
Comment=Run the official Qortal Linux setup script
Exec=konsole -e /usr/local/bin/igorcoin-qortal-official-install
Icon=applications-internet
Terminal=false
Type=Application
Categories=Network;System;
EOF

install -d -m 0755 /opt/reticulum
python -m venv /opt/reticulum/venv
/opt/reticulum/venv/bin/pip install --no-cache-dir --upgrade pip wheel
/opt/reticulum/venv/bin/pip install --no-cache-dir rns nomadnet

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

# Keep the live image browser-free; users can install a browser later if they choose.
for browser in firefox firefox-esr chromium chromium-browser brave-browser opera; do
  if pacman -Q "$browser" >/dev/null 2>&1; then
    pacman -Rns --noconfirm "$browser"
  fi
done

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

install -d -o "$LIVE_USER" -g "$LIVE_USER" "/home/$LIVE_USER/.config" "/home/$LIVE_USER/Desktop" "/home/$LIVE_USER/.config/autostart"
printf '[General]\nColorScheme=BreezeDark\nName=IgorCoin-Qortal Dark\n' > "/home/$LIVE_USER/.config/kdeglobals"
chown "$LIVE_USER:$LIVE_USER" "/home/$LIVE_USER/.config/kdeglobals"
cp -a /etc/skel/.config/autostart/. "/home/$LIVE_USER/.config/autostart/" 2>/dev/null || true
cp /etc/skel/.config/kuserfeedbackrc "/home/$LIVE_USER/.config/kuserfeedbackrc"
chown -R "$LIVE_USER:$LIVE_USER" "/home/$LIVE_USER/.config"

# Override the upstream Archiso liveuser autologin with the IgorCoin account.
install -d -m 0755 /etc/sddm.conf.d
cat > /etc/sddm.conf.d/99-igorcoin-autologin.conf <<'EOF'
[Autologin]
User=igorcoin
Session=cinnamon.desktop
Relogin=false
EOF

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
