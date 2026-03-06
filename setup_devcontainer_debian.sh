#!/usr/bin/env bash
set -euo pipefail
DEVCONTAINER_DIR=".devcontainer"
mkdir -p "$DEVCONTAINER_DIR"

# Dockerfile
cat > "$DEVCONTAINER_DIR/Dockerfile" <<'DOCKER'
FROM debian:stable-slim
ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/vscode

RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo locales xfce4 xfce4-terminal xfce4-goodies \
    tigervnc-standalone-server tigervnc-common x11-xserver-utils dbus-x11 \
    wget curl git ca-certificates python3 python3-pip supervisor fonts-dejavu-core \
  && python3 -m pip install --no-cache-dir websockify \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash -G sudo -u 1000 vscode \
  && echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode \
  && chmod 0440 /etc/sudoers.d/vscode

RUN git clone --depth 1 https://github.com/novnc/noVNC /usr/share/novnc \
  && git clone --depth 1 https://github.com/novnc/websockify /usr/share/novnc/utils/websockify

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start-desktop.sh /usr/local/bin/start-desktop.sh
RUN chmod +x /usr/local/bin/start-desktop.sh

EXPOSE 8080 5901
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
DOCKER

# Supervisor conf
cat > "$DEVCONTAINER_DIR/supervisord.conf" <<'SUPCONF'
[supervisord]
nodaemon=true
logfile=/var/log/supervisord.log
loglevel=info

[program:start-desktop]
command=/usr/local/bin/start-desktop.sh
autostart=true
autorestart=true
startretries=3
stdout_logfile=/var/log/start-desktop.log
redirect_stderr=true
SUPCONF

# Start script (usa VNC_PASS se definido, senão 'vscode')
cat > "$DEVCONTAINER_DIR/start-desktop.sh" <<'START'
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
START
chmod +x "$DEVCONTAINER_DIR/start-desktop.sh"

# devcontainer.json
cat > "$DEVCONTAINER_DIR/devcontainer.json" <<'DCJSON'
{
  "name": "Debian XFCE (noVNC)",
  "build": { "dockerfile": "Dockerfile" },
  "remoteUser": "vscode",
  "forwardPorts": [8080, 5901],
  "postCreateCommand": "echo 'Devcontainer ready. Use port 8080 to access noVNC.'",
  "customizations": {
    "vscode": {
      "extensions": ["ms-vscode-remote.remote-containers"]
    }
  }
}
DCJSON

echo ".devcontainer criado. Agora rode: chmod +x setup_devcontainer_debian.sh && ./setup_devcontainer_debian.sh"
