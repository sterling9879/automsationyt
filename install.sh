#!/bin/bash
# Viral Video SaaS - Installation Script
# For Ubuntu 22.04 VPS

set -e

echo "=========================================="
echo "  Viral Video SaaS - Installation Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo ./install.sh)${NC}"
    exit 1
fi

# Get installation directory
INSTALL_DIR="${1:-/opt/viral-video-saas}"

echo -e "${YELLOW}Installation directory: $INSTALL_DIR${NC}"
echo ""

# Update system
echo -e "${GREEN}[1/8] Updating system packages...${NC}"
apt update && apt upgrade -y

# Install dependencies
echo -e "${GREEN}[2/8] Installing dependencies...${NC}"
apt install -y \
    nginx \
    python3.11 \
    python3.11-venv \
    python3-pip \
    curl \
    git

# Create installation directory
echo -e "${GREEN}[3/8] Creating directory structure...${NC}"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Copy project files (if not already there)
if [ ! -f "$INSTALL_DIR/backend/app.py" ]; then
    echo -e "${YELLOW}Copying project files...${NC}"
    cp -r /home/user/automsationyt/* $INSTALL_DIR/
fi

# Create storage directories
mkdir -p $INSTALL_DIR/storage/{images,videos,thumbnails}
chown -R www-data:www-data $INSTALL_DIR/storage

# Setup Python virtual environment
echo -e "${GREEN}[4/8] Setting up Python environment...${NC}"
python3.11 -m venv $INSTALL_DIR/venv
source $INSTALL_DIR/venv/bin/activate
pip install --upgrade pip
pip install -r $INSTALL_DIR/backend/requirements.txt

# Configure Nginx
echo -e "${GREEN}[5/8] Configuring Nginx...${NC}"
cat > /etc/nginx/sites-available/viral-saas << 'EOF'
server {
    listen 80;
    server_name _;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Gzip
    gzip on;
    gzip_types text/plain text/css application/json application/javascript;

    # Frontend
    location / {
        root INSTALL_DIR/frontend;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    # API
    location /api {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 60s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
    }

    # WebSocket
    location /ws {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400s;
    }

    # Storage
    location /storage {
        alias INSTALL_DIR/storage;
        expires 30d;
    }

    client_max_body_size 100M;
}
EOF

# Replace INSTALL_DIR placeholder
sed -i "s|INSTALL_DIR|$INSTALL_DIR|g" /etc/nginx/sites-available/viral-saas

# Enable site
ln -sf /etc/nginx/sites-available/viral-saas /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and reload Nginx
nginx -t
systemctl restart nginx
systemctl enable nginx

# Create systemd service
echo -e "${GREEN}[6/8] Creating systemd service...${NC}"
cat > /etc/systemd/system/viral-saas.service << EOF
[Unit]
Description=Viral Video SaaS Backend
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$INSTALL_DIR/backend
Environment="PATH=$INSTALL_DIR/venv/bin"
Environment="PYTHONPATH=$INSTALL_DIR/backend"
ExecStart=$INSTALL_DIR/venv/bin/uvicorn app:app --host 127.0.0.1 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
echo -e "${GREEN}[7/8] Setting permissions...${NC}"
chown -R www-data:www-data $INSTALL_DIR
chmod -R 755 $INSTALL_DIR

# Start service
echo -e "${GREEN}[8/8] Starting service...${NC}"
systemctl daemon-reload
systemctl enable viral-saas
systemctl start viral-saas

# Wait for service to start
sleep 3

# Check status
if systemctl is-active --quiet viral-saas; then
    echo ""
    echo -e "${GREEN}=========================================="
    echo "  Installation Complete!"
    echo "==========================================${NC}"
    echo ""
    echo -e "  Access URL: ${YELLOW}http://$(hostname -I | awk '{print $1}')${NC}"
    echo ""
    echo "  Service commands:"
    echo "    sudo systemctl status viral-saas"
    echo "    sudo systemctl restart viral-saas"
    echo "    sudo journalctl -u viral-saas -f"
    echo ""
    echo -e "${GREEN}  Next steps:${NC}"
    echo "    1. Open the URL above in your browser"
    echo "    2. Click the settings icon (gear)"
    echo "    3. Enter your Freepik API key"
    echo "    4. Start generating videos!"
    echo ""
    echo "  Get your Freepik API key at:"
    echo -e "    ${YELLOW}https://www.freepik.com/api${NC}"
    echo ""
else
    echo -e "${RED}Service failed to start. Check logs:${NC}"
    echo "  sudo journalctl -u viral-saas -n 50"
fi
