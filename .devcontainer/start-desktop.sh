#!/usr/bin/env bash
set -euo pipefail
USER_HOME="/home/vscode"
VNC_PASS="${VNC_PASS:-vscode}"

mkdir -p "$USER_HOME/.vnc"
cat > "$USER_HOME/.vnc/xstartup" <<'XSTART'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4 &
XSTART
chmod +x "$USER_HOME/.vnc/xstartup"
chown -R vscode:vscode "$USER_HOME/.vnc"

echo "$VNC_PASS" | vncpasswd -f > "$USER_HOME/.vnc/passwd"
chmod 600 "$USER_HOME/.vnc/passwd"
chown vscode:vscode "$USER_HOME/.vnc/passwd"

# start VNC on :1 (5901)
su - vscode -c "vncserver :1 -geometry 1280x800 -depth 24"

# start websockify to serve noVNC
if command -v websockify >/dev/null 2>&1; then
  websockify --web=/usr/share/novnc 8080 localhost:5901 &
else
  python3 /usr/share/novnc/utils/websockify/run 8080 localhost:5901 &
fi

tail -f /var/log/start-desktop.log
