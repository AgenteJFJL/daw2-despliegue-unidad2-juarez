#!/bin/bash
set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1   # guarda todo en un log para depurar

############ 1. Instalar Docker Engine + Compose (repo oficial) ############
apt-get update -y
apt-get install -y ca-certificates curl openssl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
usermod -aG docker ubuntu

############ 2. Obtener la IP pública (metadatos IMDSv2) ############
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
        http://169.254.169.254/latest/meta-data/public-ipv4)

############ 3. Crear estructura del proyecto ############
mkdir -p /opt/proyecto/{app,nginx,certs}
cd /opt/proyecto

############ 4. Certificado SSL autofirmado ############
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout certs/selfsigned.key -out certs/selfsigned.crt \
  -subj "/C=ES/O=Pio Baroja/CN=${PUBLIC_IP}" \
  -addext "subjectAltName=IP:${PUBLIC_IP}"

############ 5. Fecha de despliegue ############
echo "DEPLOY_DATE=$(date '+%d/%m/%Y %H:%M:%S')" > .env

############ 6. Ficheros de la aplicación ############
cat > app/requirements.txt <<'EOF'
flask
gunicorn
EOF

cat > app/app.py <<'EOF'
import os
from flask import Flask

app = Flask(__name__)

@app.route("/")
def index():
    fecha = os.environ.get("DEPLOY_DATE", "desconocida")
    return f"""
    <html>
      <head><title>UT2-RA2</title></head>
      <body style="font-family: sans-serif; text-align: center; margin-top: 10%;">
        <h1>Despliegue Nginx + Flask + SSL</h1>
        <p><b>Alumno:</b> Jean Franco Juarez Lozano</p>
        <p><b>Centro-Ciclo-Grupo:</b> Pío Baroja - DAW - TU GRUPO</p>
        <p><b>Fecha de despliegue:</b> {fecha}</p>
      </body>
    </html>
    """
EOF

cat > app/Dockerfile <<'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 5000
CMD ["gunicorn", "-b", "0.0.0.0:5000", "app:app"]
EOF

############ 7. Configuración de Nginx ############
cat > nginx/default.conf <<'EOF'
server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}
server {
    listen 443 ssl;
    server_name _;
    ssl_certificate     /etc/nginx/certs/selfsigned.crt;
    ssl_certificate_key /etc/nginx/certs/selfsigned.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    location / {
        proxy_pass http://flask:5000;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

############ 8. docker-compose.yml ############
cat > docker-compose.yml <<'EOF'
services:
  flask:
    build: ./app
    container_name: flask
    environment:
      - DEPLOY_DATE=${DEPLOY_DATE}
    expose:
      - "5000"
    networks:
      - red_privada
    restart: unless-stopped

  nginx:
    image: nginx:stable
    container_name: nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ./certs:/etc/nginx/certs:ro
    depends_on:
      - flask
    networks:
      - red_privada
    restart: unless-stopped

networks:
  red_privada:
    driver: bridge
EOF

############ 9. Levantar todo ############
docker compose up -d --build
