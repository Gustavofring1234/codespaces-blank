#!/usr/bin/env bash
set -euo pipefail

# Nome dos arquivos / diretórios
DEVCONTAINER_DIR=".devcontainer"
DOCKERFILE="$DEVCONTAINER_DIR/Dockerfile"
DEVCONTAINER_JSON="$DEVCONTAINER_DIR/devcontainer.json"
SUPERVISOR_CONF="$DEVCONTAINER_DIR/supervisord.conf"
START_SCRIPT="$DEVCONTAINER_DIR/start-desktop.sh"
README="$DEVCONTAINER_DIR/README.md"

mkdir -p "$DEVCONTAINER_DIR"

cat > "$DOCKERFILE" <<'DOCKER'
# Use Debian stable slim como base
FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/vscode

# Instala pacotes necessários: XFCE, TigerVNC, ferramentas, supervisor, git, pip
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    locales \
    xfce4 xfce4-terminal xfce4-goodies \
    tigervnc-standalone-server tigervnc-common \
    x11-xserver-utils dbus-x11 \
    wget curl git ca-certificates \
    python3 python3-pip \
    supervisor \
    fonts-dejavu-core \
  && python3 -m pip install --no-cache-dir websockify \
  && rm -rf /var/lib/apt/lists/*

# Criar usuário vscode (UID 1000) compatível com Codespaces pattern
RUN useradd -m -s /bin/bash -G sudo -u 1000 vscode \
  && echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode \
  && chmod 0440 /etc/sudoers.d/vscode

# Clonar noVNC (web UI) e websockify util se quiser usar versão local
RUN git clone --depth 1 https://github.com/novnc/noVNC /usr/share/novnc \
  && git clone --depth 1 https://github.com/novnc/websockify /usr/share/novnc/utils/websockify

# Copiar scripts e configs (serão adicionados pelo devcontainer build context)
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start-desktop.sh /usr/local/bin/start-desktop.sh
RUN chmod +x /usr/local/bin/start-desktop.sh

# Expor portas: 8080 para noVNC (browser), 5901 para VNC direto
EXPOSE 8080 5901

# Iniciar supervisord quando container inicia
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
DOCKER

cat > "$SUPERVISOR_CONF" <<'SUPCONF'
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

cat > "$START_SCRIPT" <<'START'
#!/usr/bin/env bash
set -euo pipefail

# Este script é executado como root por supervisord.
# Vai preparar o xstartup do VNC, setar senha padrão (vscode) e iniciar VNC + websockify (noVNC).

USER_HOME="/home/vscode"
VNC_PASS="vscode"   # Mude depois por segurança!

# 1) Criar xstartup para XFCE
mkdir -p "$USER_HOME/.vnc"
cat > "$USER_HOME/.vnc/xstartup" <<'XSTART'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4 &
XSTART
chmod +x "$USER_HOME/.vnc/xstartup"
chown -R vscode:vscode "$USER_HOME/.vnc"

# 2) Criar senha VNC não-interativa
# O vncpasswd -f lê a senha da entrada e escreve o hash no stdout.
echo "$VNC_PASS" | vncpasswd -f > "$USER_HOME/.vnc/passwd"
chmod 600 "$USER_HOME/.vnc/passwd"
chown vscode:vscode "$USER_HOME/.vnc/passwd"

# 3) Export DISPLAY e iniciar VNC server na :1 (porta 5901)
# Usamos tigerVNC (vncserver)
su - vscode -c "vncserver :1 -geometry 1280x800 -depth 24"

# 4) Iniciar websockify para fazer bridge websocket -> VNC (noVNC)
# websockify já foi instalado via pip ou via repository clonado
# Serve arquivos no /usr/share/novnc
if command -v websockify >/dev/null 2>&1; then
  WEBSOCKIFY_CMD="websockify --web=/usr/share/novnc 8080 localhost:5901"
else
  # fallback: executar util websockify clonado
  WEBSOCKIFY_CMD="python3 /usr/share/novnc/utils/websockify/run 8080 localhost:5901"
fi

# run websockify in background
$WEBSOCKIFY_CMD &

# 5) keep container alive (supervisord controla, mas prevenir saída)
# tail logs so supervisord can monitor output
tail -f /var/log/start-desktop.log
START

# Make files readable / executable
chmod +x "$START_SCRIPT"
chmod 644 "$SUPERVISOR_CONF"

# devcontainer.json
cat > "$DEVCONTAINER_JSON" <<'DCJSON'
{
  "name": "Debian XFCE (noVNC)",
  "build": {
    "dockerfile": "Dockerfile"
  },
  "remoteUser": "vscode",
  "forwardPorts": [8080, 5901],
  "postCreateCommand": "echo 'Devcontainer ready. Use port 8080 to access noVNC.'",
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-vscode-remote.remote-containers"
      ]
    }
  }
}
DCJSON

cat > "$README" <<'RMD'
# Devcontainer Debian + XFCE + noVNC

- Porta 8080 -> noVNC (acesso via navegador)
- Porta 5901 -> VNC direto (ex: TigerVNC viewer)
- Senha VNC padrão: vscode  (mude após uso)

### Uso
1. Commit & push deste repositório com a pasta .devcontainer.
2. Abra no GitHub Codespaces e crie um Codespace.
3. Aguarde build; em seguida abra a porta 8080 no painel de portas do Codespaces para acessar a interface gráfica.

RMD

echo ".devcontainer criado com sucesso. Faça commit e abra um Codespace para usar."