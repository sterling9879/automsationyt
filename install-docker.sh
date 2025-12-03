#!/bin/bash
# Viral Video SaaS - Docker Installation Script
# For any Linux system with Docker

set -e

echo "=========================================="
echo "  Viral Video SaaS - Docker Installation"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker not found. Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh

    # Add current user to docker group
    usermod -aG docker $USER
    echo -e "${YELLOW}Please log out and log back in, then run this script again.${NC}"
    exit 0
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}Docker Compose not found. Installing...${NC}"
    apt-get update && apt-get install -y docker-compose-plugin
fi

# Get installation directory
INSTALL_DIR="${1:-$(pwd)}"
cd $INSTALL_DIR

echo -e "${GREEN}Installing in: $INSTALL_DIR${NC}"
echo ""

# Create storage directories
echo -e "${GREEN}[1/3] Creating directories...${NC}"
mkdir -p storage/{images,videos,thumbnails}
mkdir -p backend/database

# Build and start containers
echo -e "${GREEN}[2/3] Building Docker containers...${NC}"
docker compose build --no-cache

echo -e "${GREEN}[3/3] Starting services...${NC}"
docker compose up -d

# Wait for services
echo "Waiting for services to start..."
sleep 5

# Check health
if curl -s http://localhost/api/health | grep -q "healthy"; then
    echo ""
    echo -e "${GREEN}=========================================="
    echo "  Docker Installation Complete!"
    echo "==========================================${NC}"
    echo ""
    echo -e "  Access URL: ${YELLOW}http://$(hostname -I | awk '{print $1}')${NC}"
    echo ""
    echo "  Docker commands:"
    echo "    docker compose ps       - Check status"
    echo "    docker compose logs -f  - View logs"
    echo "    docker compose restart  - Restart services"
    echo "    docker compose down     - Stop services"
    echo ""
    echo -e "${GREEN}  Next steps:${NC}"
    echo "    1. Open the URL above in your browser"
    echo "    2. Click the settings icon"
    echo "    3. Enter your Freepik API key"
    echo "    4. Start generating videos!"
    echo ""
    echo "  Get your Freepik API key at:"
    echo -e "    ${YELLOW}https://www.freepik.com/api${NC}"
    echo ""
else
    echo -e "${RED}Services may not be fully ready. Check:${NC}"
    echo "  docker compose ps"
    echo "  docker compose logs"
fi
