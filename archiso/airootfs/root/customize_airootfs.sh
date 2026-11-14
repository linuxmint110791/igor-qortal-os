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

CORE_JSON="$(curl -fsSL https://api.github.com/repos/Qortal/qortal/releases/latest)"
CORE_URL="$(jq -er '[.assets[] | select(.name | test("qortal.*\\.jar$"; "i"))][0].browser_download_url' <<<"$CORE_JSON")"
curl -fL --retry 3 --retry-delay 2 "$CORE_URL" -o /opt/qortal/core/qortal.jar
chown qortal:qortal /opt/qortal/core/qortal.jar

HUB_JSON="$(curl -fsSL https://api.github.com/repos/Qortal/Qortal-Hub/releases/latest)"
HUB_URL="$(jq -er '[.assets[] | select((.name | test("x86_64|x64|Qortal-Hub\\.AppImage$"; "i")) and (.name | endswith(".AppImage")))][0].browser_download_url' <<<"$HUB_JSON")"
curl -fL --retry 3 --retry-delay 2 "$HUB_URL" -o /opt/qortal/hub/Qortal-Hub.AppImage
chmod 0755 /opt/qortal/hub/Qortal-Hub.AppImage

install -d -m 0755 /usr/share/applications
MESH_JSON="$(curl -fsSL https://api.github.com/repos/liamcottle/reticulum-meshchat/releases/latest)"
MESH_URL="$(jq -er '[.assets[] | select((.name | test("linux.*\\.AppImage$"; "i")))][0].browser_download_url' <<<"$MESH_JSON")"
install -d -m 0755 /opt/qortal/meshchat
curl -fL --retry 3 --retry-delay 2 "$MESH_URL" -o /opt/qortal/meshchat/ReticulumMeshChat.AppImage
chmod 0755 /opt/qortal/meshchat/ReticulumMeshChat.AppImage

cat > /usr/share/applications/qortal-core.desktop <<'EOF'
[Desktop Entry]
Name=Qortal Core Web Interface
Comment=Open the local Qortal Core interface
Exec=xdg-open https://127.0.0.1:12391
Icon=applications-internet
Terminal=false
Type=Application
Categories=Network;
EOF
cat > /usr/share/applications/qortal-hub.desktop <<'EOF'
[Desktop Entry]
Name=Qortal Hub
Comment=Decentralized Qortal interface
Exec=/opt/qortal/hub/Qortal-Hub.AppImage
Icon=applications-internet
Terminal=false
Type=Application
Categories=Network;
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
systemctl enable NetworkManager.service systemd-resolved.service sddm.service bluetooth.service docker.service qortal.service reticulum.service
systemctl enable podman.socket || true
systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service

cat > /usr/share/applications/calamares.desktop <<'EOF'
[Desktop Entry]
Name=Install IgorCoin-Qortal OS
Comment=Install IgorCoin-Qortal OS
Exec=pkexec calamares
Icon=system-software-install
Terminal=false
Type=Application
Categories=System;
EOF
echo "Live image configuration completed."
