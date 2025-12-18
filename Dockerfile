FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. Install Dasar & Desktop Environment
RUN apt update -y && apt install --no-install-recommends -y \
    xfce4 xfce4-goodies tigervnc-standalone-server novnc websockify sudo xterm \
    init systemd snapd vim net-tools curl wget git tzdata nginx openssl ca-certificates

# 2. Install Firefox & X11
RUN apt update -y && apt install -y dbus-x11 x11-utils x11-xserver-utils x11-apps software-properties-common
RUN add-apt-repository ppa:mozillateam/ppa -y && \
    echo 'Package: *' > /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin: release o=LP-PPA-moz1illateam' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox && \
    apt update -y && apt install -y firefox xubuntu-icon-theme

# 3. Install Node.js 22 & FFmpeg (PENTING: Langkah ini yang tadi gagal)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs ffmpeg

# 4. Setup StreamFlow (Otomatis saat build)
WORKDIR /streamflow
RUN git clone https://github.com/bangtutorial/streamflow . && \
    npm install && \
    node generate-secret.js && \
    echo "PORT=7575\nNODE_ENV=development" > .env

# Kembali ke root
WORKDIR /root
RUN touch /root/.Xauthority

# Port utama Railway
EXPOSE 8080

CMD bash -c "\
    # Setup Nginx sebagai Reverse Proxy
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
        } \
        location /vnc/ { \
            proxy_pass http://127.0.0.1:6081/; \
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
    # Jalankan VNC & Websockify
    vncserver -localhost no -SecurityTypes None -geometry 1024x768 --I-KNOW-THIS-IS-INSECURE && \
    websockify -D --web=/usr/share/novnc/ 6081 localhost:5901 && \
    \
    # Jalankan StreamFlow di background
    cd /streamflow && npm run dev & \
    \
    # Jalankan Nginx di foreground
    nginx -g 'daemon off;' \
    "
