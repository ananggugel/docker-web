FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. Install Dasar, Desktop, Node.js & FFmpeg
RUN apt update -y && apt install --no-install-recommends -y \
    xfce4 xfce4-goodies tigervnc-standalone-server novnc websockify sudo xterm \
    init systemd snapd vim net-tools curl wget git tzdata nginx openssl ca-certificates && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs ffmpeg git

# 2. Install Firefox (Metode yang kamu konfirmasi bekerja)
RUN apt update -y && apt install -y dbus-x11 x11-utils x11-xserver-utils x11-apps software-properties-common
RUN add-apt-repository ppa:mozillateam/ppa -y
RUN echo 'Package: *' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox
RUN echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:jammy";' | tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox
RUN apt update -y && apt install -y firefox xubuntu-icon-theme

WORKDIR /root
RUN touch /root/.Xauthority

# Port Railway
EXPOSE 8080

CMD bash -c "\
    # Konfigurasi Nginx Reverse Proxy
    rm -f /etc/nginx/sites-enabled/default && \
    echo \"server { \
        listen \$PORT; \
        server_name _; \
        location / { \
            proxy_pass http://127.0.0.1:7575; \
            proxy_http_version 1.1; \
            proxy_set_header Upgrade \\\$http_upgrade; \
            proxy_set_header Connection 'upgrade'; \
            proxy_set_header Host \\\$host; \
            proxy_cache_bypass \\\$http_upgrade; \
        } \
        location /vnc.html { \
            proxy_pass http://127.0.0.1:6081/vnc.html; \
        } \
        location /websockify { \
            proxy_pass http://127.0.0.1:6081/; \
            proxy_http_version 1.1; \
            proxy_set_header Upgrade \\\$http_upgrade; \
            proxy_set_header Connection 'upgrade'; \
            proxy_read_timeout 61s; \
        } \
    }\" > /etc/nginx/conf.d/default.conf && \
    \
    # Jalankan VNC & Websockify di background
    vncserver -localhost no -SecurityTypes None -geometry 1024x768 --I-KNOW-THIS-IS-INSECURE && \
    websockify -D --web=/usr/share/novnc/ 6081 localhost:5901 && \
    \
    # Jalankan Nginx (Ini yang memegang port publik)
    nginx -g 'daemon off;' \
    "
