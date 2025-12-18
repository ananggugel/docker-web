FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app

# Install base + nginx + node deps
RUN apt update && apt install -y \
    curl ca-certificates gnupg git ffmpeg \
    nginx \
    tigervnc-standalone-server \
    novnc websockify \
    xfce4 xfce4-goodies xterm \
    dbus-x11 x11-utils x11-xserver-utils x11-apps \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt install -y nodejs

# Clone Streamflow
RUN git clone https://github.com/bangtutorial/streamflow /app/streamflow
WORKDIR /app/streamflow
RUN npm install && node generate-secret.js

# Streamflow env
RUN echo "HOST=0.0.0.0" > .env \
 && echo "PORT=3000" >> .env

# nginx config
RUN rm -f /etc/nginx/sites-enabled/default
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 6080

CMD bash -c "\
vncserver -localhost no -SecurityTypes None -geometry 1024x768 --I-KNOW-THIS-IS-INSECURE && \
openssl req -new -subj \"/C=JP\" -x509 -days 365 -nodes -out /self.pem -keyout /self.pem && \
websockify -D --web=/usr/share/novnc/ --cert=/self.pem 6081 localhost:5901 && \
npm run dev --prefix /app/streamflow & \
nginx -g 'daemon off;'"
