FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app

RUN apt update -y && apt install --no-install-recommends -y \
xfce4 xfce4-goodies tigervnc-standalone-server novnc websockify sudo xterm \
dbus-x11 x11-utils x11-xserver-utils x11-apps \
vim net-tools curl wget git tzdata ffmpeg nginx ca-certificates gnupg \
software-properties-common \
&& rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt install -y nodejs

RUN git clone https://github.com/bangtutorial/streamflow /app/streamflow && cd /app/streamflow && npm install && node generate-secret.js && echo "HOST=0.0.0.0" > .env && echo "PORT=3000" >> .env

RUN rm -f /etc/nginx/sites-enabled/default && echo 'server { listen 6080; server_name _; location / { proxy_pass http://127.0.0.1:6081; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; } location /streamflow/ { proxy_pass http://127.0.0.1:3000/; proxy_set_header Host $host; proxy_set_header X-Real-IP $remote_addr; proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; }}' > /etc/nginx/conf.d/default.conf

RUN touch /root/.Xauthority

EXPOSE 6080

CMD bash -c "vncserver -localhost no -SecurityTypes None -geometry 1024x768 --I-KNOW-THIS-IS-INSECURE && openssl req -new -subj \"/C=JP\" -x509 -days 365 -nodes -out /self.pem -keyout /self.pem && websockify -D --web=/usr/share/novnc/ --cert=/self.pem 6081 localhost:5901 && npm run dev --prefix /app/streamflow & nginx -g 'daemon off;'"
