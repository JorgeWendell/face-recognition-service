#!/bin/bash

# Deploy Rápido - Para quando o código já está no servidor

set -e

APP_DIR="/var/www/face-recognition-service"
VENV_DIR="$APP_DIR/venv"
SERVICE_NAME="face-recognition-service"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Deploy Rápido - Face Recognition Service${NC}"
echo ""

# Verificar se está no diretório correto
if [ ! -f "app.py" ] && [ ! -f "app_opencv.py" ]; then
    echo "Execute este script dentro do diretório face-recognition-service"
    exit 1
fi

# Atualizar código (se for repositório Git)
if [ -d ".git" ]; then
    echo -e "${YELLOW}[*] Atualizando código do Git...${NC}"
    git pull origin main || true
fi

# Ativar ambiente virtual
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${YELLOW}[*] Criando ambiente virtual...${NC}"
    python3 -m venv venv
fi

source venv/bin/activate

# Atualizar dependências
echo -e "${YELLOW}[*] Atualizando dependências...${NC}"
pip install --upgrade pip -q

if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt -q
elif [ -f "requirements-simple.txt" ]; then
    pip install -r requirements-simple.txt -q
fi

# Reiniciar serviço PM2
if command -v pm2 &> /dev/null; then
    echo -e "${YELLOW}[*] Reiniciando serviço...${NC}"
    pm2 restart $SERVICE_NAME || pm2 start ecosystem.config.js
    pm2 save
fi

echo -e "${GREEN}[✓] Deploy concluído!${NC}"
echo ""
echo "Verificar status: pm2 status"
echo "Ver logs: pm2 logs $SERVICE_NAME"

