#!/bin/bash
# =============================================================================
# Viral Video SaaS - Quick Start Script
# Para testar localmente sem Docker
# =============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         VIRAL VIDEO SAAS - QUICK START                    ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Verificar Python
echo -e "${YELLOW}[1/5] Verificando Python...${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    echo -e "${RED}Python não encontrado. Por favor, instale Python 3.11+${NC}"
    exit 1
fi

PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1,2)
echo -e "  Python encontrado: $PYTHON_VERSION"

# Criar ambiente virtual
echo -e "${YELLOW}[2/5] Criando ambiente virtual...${NC}"
if [ ! -d "venv" ]; then
    $PYTHON_CMD -m venv venv
    echo -e "  ${GREEN}Ambiente virtual criado${NC}"
else
    echo -e "  Ambiente virtual já existe"
fi

# Ativar ambiente virtual
source venv/bin/activate

# Instalar dependências
echo -e "${YELLOW}[3/5] Instalando dependências Python...${NC}"
pip install --upgrade pip -q
pip install -r backend/requirements.txt -q
echo -e "  ${GREEN}Dependências instaladas${NC}"

# Criar diretórios de storage
echo -e "${YELLOW}[4/5] Criando diretórios...${NC}"
mkdir -p storage/images storage/videos storage/thumbnails
mkdir -p backend/database
echo -e "  ${GREEN}Diretórios criados${NC}"

# Iniciar servidor
echo -e "${YELLOW}[5/5] Iniciando servidor...${NC}"
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    SERVIDOR INICIADO!                     ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BLUE}Acesse:${NC} http://localhost:8000"
echo -e "  ${BLUE}Frontend:${NC} Abra frontend/index.html no navegador"
echo ""
echo -e "  ${YELLOW}Para parar: Ctrl+C${NC}"
echo ""

cd backend
$PYTHON_CMD -m uvicorn app:app --host 0.0.0.0 --port 8000 --reload
