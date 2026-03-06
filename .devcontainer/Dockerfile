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
