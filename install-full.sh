#!/bin/bash
# =============================================================================
# VIRAL VIDEO SAAS - INSTALACAO COMPLETA
# Compativel com Ubuntu 20.04, 22.04, Debian 11, 12
# =============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Banner
clear
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║   ██╗   ██╗██╗██████╗  █████╗ ██╗         ██╗   ██╗██╗██████╗ ███████╗   ║
║   ██║   ██║██║██╔══██╗██╔══██╗██║         ██║   ██║██║██╔══██╗██╔════╝   ║
║   ██║   ██║██║██████╔╝███████║██║         ██║   ██║██║██║  ██║█████╗     ║
║   ╚██╗ ██╔╝██║██╔══██╗██╔══██║██║         ╚██╗ ██╔╝██║██║  ██║██╔══╝     ║
║    ╚████╔╝ ██║██║  ██║██║  ██║███████╗     ╚████╔╝ ██║██████╔╝███████╗   ║
║     ╚═══╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝      ╚═══╝  ╚═╝╚═════╝ ╚══════╝   ║
║                                                                           ║
║                    SAAS - GERADOR DE VIDEOS VIRAIS                        ║
║                         Powered by Freepik AI                             ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Verificar root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERRO] Execute como root: sudo $0${NC}"
    exit 1
fi

# Configuracoes
INSTALL_DIR="/opt/viral-video-saas"
SERVICE_NAME="viral-saas"
SERVICE_USER="www-data"
PYTHON_VERSION="3.11"

# Detectar SO
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    echo -e "${BLUE}Sistema detectado: $OS $VER${NC}"
}

# Funcao de log
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] AVISO:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERRO:${NC} $1"
}

# Verificar IP
get_ip() {
    IP=$(hostname -I | awk '{print $1}')
    if [ -z "$IP" ]; then
        IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
    fi
    echo $IP
}

# =============================================================================
# INSTALACAO
# =============================================================================

echo ""
detect_os
echo ""

# Passo 1: Atualizar sistema
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
log "[1/10] Atualizando sistema..."
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
apt update -qq
apt upgrade -y -qq

# Passo 2: Instalar dependencias
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
log "[2/10] Instalando dependencias do sistema..."
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
apt install -y -qq \
    nginx \
    curl \
    wget \
    git \
    software-properties-common \
    build-essential \
    libssl-dev \
    libffi-dev

# Passo 3: Instalar Python
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
log "[3/10] Instalando Python ${PYTHON_VERSION}..."
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

# Adicionar repositorio deadsnakes para Python mais recente (se necessario)
if ! command -v python${PYTHON_VERSION} &> /dev/null; then
    add-apt-repository ppa:deadsnakes/ppa -y 2>/dev/null || true
    apt update -qq
fi

apt install -y -qq \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-venv \
    python${PYTHON_VERSION}-dev \
    python3-pip

# Verificar instalacao Python
if command -v python${PYTHON_VERSION} &> /dev/null; then
    log "Python ${PYTHON_VERSION} instalado com sucesso"
else
    log_warn "Python ${PYTHON_VERSION} nao disponivel, usando python3"
    PYTHON_VERSION="3"
fi

# Passo 4: Criar estrutura de diretorios
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
log "[4/10] Criando estrutura de diretorios..."
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

mkdir -p ${INSTALL_DIR}/{backend,frontend,storage}
mkdir -p ${INSTALL_DIR}/backend/{routes,services,database,workers}
mkdir -p ${INSTALL_DIR}/frontend/{css,js,assets}
mkdir -p ${INSTALL_DIR}/storage/{images,videos,thumbnails}
mkdir -p /var/log/viral-saas

# Passo 5: Copiar arquivos do projeto
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
log "[5/10] Copiando arquivos do projeto..."
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -d "${SCRIPT_DIR}/backend" ]; then
    cp -r ${SCRIPT_DIR}/backend/* ${INSTALL_DIR}/backend/
    cp -r ${SCRIPT_DIR}/frontend/* ${INSTALL_DIR}/frontend/
    log "Arquivos copiados de ${SCRIPT_DIR}"
else
    log_error "Diretorio backend nao encontrado em ${SCRIPT_DIR}"
    exit 1
fi

# Passo 6: Configurar ambiente Python
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
log "[6/10] Configurando ambiente Python virtual..."
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

cd ${INSTALL_DIR}
python${PYTHON_VERSION} -m venv venv
source venv/bin/activate

pip install --upgrade pip -q
pip install -r backend/requirements.txt -q

log "Dependencias Python instaladas"

# Passo 7: Configurar Nginx
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
log "[7/10] Configurando Nginx..."
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

cat > /etc/nginx/sites-available/${SERVICE_NAME} << 'NGINX_EOF'
# Viral Video SaaS - Nginx Configuration
upstream viral_backend {
    server 127.0.0.1:8000;
    keepalive 32;
}

server {
    listen 80;
    server_name _;

    # Logs
    access_log /var/log/nginx/viral-saas-access.log;
    error_log /var/log/nginx/viral-saas-error.log;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript image/svg+xml;

    # Frontend - arquivos estaticos
    location / {
        root /opt/viral-video-saas/frontend;
        index index.html;
        try_files $uri $uri/ /index.html;

        # Cache para assets estaticos
        location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 30d;
            add_header Cache-Control "public, immutable";
        }
    }

    # API Backend
    location /api {
        proxy_pass http://viral_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";

        # Timeouts para requisicoes longas
        proxy_connect_timeout 60s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;

        # Buffer settings
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }

    # WebSocket para progresso em tempo real
    location /ws {
        proxy_pass http://viral_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # WebSocket timeout longo
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    # Storage - arquivos gerados
    location /storage {
        alias /opt/viral-video-saas/storage;
        expires 7d;
        add_header Cache-Control "public";

        # Suporte a streaming de video
        location ~* \.(mp4|webm|mov)$ {
            add_header Accept-Ranges bytes;
            add_header Cache-Control "public, max-age=604800";
        }
    }

    # Negar acesso a arquivos ocultos
    location ~ /\. {
        deny all;
    }

    # Tamanho maximo de upload
    client_max_body_size 100M;
    client_body_buffer_size 10M;
}
NGINX_EOF

# Ativar site
ln -sf /etc/nginx/sites-available/${SERVICE_NAME} /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Testar e recarregar Nginx
nginx -t
systemctl restart nginx
systemctl enable nginx

log "Nginx configurado e iniciado"

# Passo 8: Criar servico systemd
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
log "[8/10] Criando servico systemd..."
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

cat > /etc/systemd/system/${SERVICE_NAME}.service << SERVICE_EOF
[Unit]
Description=Viral Video SaaS - AI Video Generator
Documentation=https://github.com/seu-repo/viral-video-saas
After=network.target nginx.service
Wants=nginx.service

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${INSTALL_DIR}/backend
Environment="PATH=${INSTALL_DIR}/venv/bin:/usr/local/bin:/usr/bin"
Environment="PYTHONPATH=${INSTALL_DIR}/backend"
Environment="PYTHONUNBUFFERED=1"

ExecStart=${INSTALL_DIR}/venv/bin/uvicorn app:app --host 127.0.0.1 --port 8000 --workers 2

Restart=always
RestartSec=5
StartLimitBurst=5
StartLimitInterval=60

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

# Security
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${INSTALL_DIR}/storage ${INSTALL_DIR}/backend/database /var/log/viral-saas
PrivateTmp=true

[Install]
WantedBy=multi-user.target
SERVICE_EOF

log "Servico systemd criado"

# Passo 9: Configurar permissoes
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
log "[9/10] Configurando permissoes..."
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

chown -R ${SERVICE_USER}:${SERVICE_USER} ${INSTALL_DIR}
chown -R ${SERVICE_USER}:${SERVICE_USER} /var/log/viral-saas
chmod -R 755 ${INSTALL_DIR}
chmod -R 775 ${INSTALL_DIR}/storage

log "Permissoes configuradas"

# Passo 10: Iniciar servicos
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
log "[10/10] Iniciando servicos..."
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl start ${SERVICE_NAME}

# Aguardar inicializacao
sleep 3

# Verificar status
if systemctl is-active --quiet ${SERVICE_NAME}; then
    SERVICE_STATUS="${GREEN}ATIVO${NC}"
else
    SERVICE_STATUS="${RED}INATIVO${NC}"
fi

if systemctl is-active --quiet nginx; then
    NGINX_STATUS="${GREEN}ATIVO${NC}"
else
    NGINX_STATUS="${RED}INATIVO${NC}"
fi

# =============================================================================
# RESULTADO FINAL
# =============================================================================

IP_ADDRESS=$(get_ip)

echo ""
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║                    ✅ INSTALACAO CONCLUIDA COM SUCESSO!                   ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                      STATUS DOS SERVICOS                       ${CYAN}║${NC}"
echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  Backend (${SERVICE_NAME}):  ${SERVICE_STATUS}                              ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  Nginx:                  ${NGINX_STATUS}                              ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                        ACESSO                                  ${CYAN}║${NC}"
echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${YELLOW}URL:${NC} http://${IP_ADDRESS}                                   ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                    COMANDOS UTEIS                              ${CYAN}║${NC}"
echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  Ver status:    ${YELLOW}sudo systemctl status ${SERVICE_NAME}${NC}         ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  Ver logs:      ${YELLOW}sudo journalctl -u ${SERVICE_NAME} -f${NC}         ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  Reiniciar:     ${YELLOW}sudo systemctl restart ${SERVICE_NAME}${NC}        ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  Parar:         ${YELLOW}sudo systemctl stop ${SERVICE_NAME}${NC}           ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                    PROXIMOS PASSOS                             ${CYAN}║${NC}"
echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  1. Abra ${YELLOW}http://${IP_ADDRESS}${NC} no navegador              ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  2. Clique no icone de ${YELLOW}engrenagem${NC} (configuracoes)        ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  3. Insira sua ${YELLOW}API Key do Freepik${NC}                        ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  4. Comece a gerar videos!                                    ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}Obtenha sua API Key em:${NC}                                   ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${YELLOW}https://www.freepik.com/api${NC}                               ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}Voce recebe 5 EUR em creditos gratis!${NC}                     ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Salvar informacoes de instalacao
cat > ${INSTALL_DIR}/install-info.txt << INFO_EOF
===========================================
VIRAL VIDEO SAAS - INFORMACOES DE INSTALACAO
===========================================

Data de Instalacao: $(date)
Diretorio: ${INSTALL_DIR}
Servico: ${SERVICE_NAME}
Usuario: ${SERVICE_USER}

URL de Acesso: http://${IP_ADDRESS}

Comandos:
  Status:    sudo systemctl status ${SERVICE_NAME}
  Logs:      sudo journalctl -u ${SERVICE_NAME} -f
  Reiniciar: sudo systemctl restart ${SERVICE_NAME}
  Parar:     sudo systemctl stop ${SERVICE_NAME}

Diretorios:
  Backend:   ${INSTALL_DIR}/backend
  Frontend:  ${INSTALL_DIR}/frontend
  Storage:   ${INSTALL_DIR}/storage
  Logs:      /var/log/viral-saas

===========================================
INFO_EOF

log "Informacoes salvas em ${INSTALL_DIR}/install-info.txt"
echo ""
