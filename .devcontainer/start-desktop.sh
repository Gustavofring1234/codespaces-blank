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
