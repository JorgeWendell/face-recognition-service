#!/bin/bash

# Script para instalar dependências do face_recognition

set -e

APP_DIR="/var/www/face-recognition-service"
VENV_DIR="$APP_DIR/venv"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Instalando dependências do face_recognition...${NC}"
echo ""

cd $APP_DIR

if [ ! -d "$VENV_DIR" ]; then
    echo -e "${RED}[✗] Ambiente virtual não encontrado!${NC}"
    echo -e "${YELLOW}[*] Criando ambiente virtual...${NC}"
    python3 -m venv $VENV_DIR
fi

# Ativar ambiente virtual
echo -e "${YELLOW}[*] Ativando ambiente virtual...${NC}"
source $VENV_DIR/bin/activate

# Verificar se pip está do venv
if ! which pip | grep -q "$VENV_DIR"; then
    echo -e "${RED}[✗] pip não está usando o ambiente virtual!${NC}"
    echo -e "${YELLOW}[*] Usando pip do venv diretamente...${NC}"
    PIP_CMD="$VENV_DIR/bin/pip"
else
    PIP_CMD="pip"
fi

echo -e "${YELLOW}[*] Atualizando pip...${NC}"
$PIP_CMD install --upgrade pip -q

echo -e "${YELLOW}[*] Instalando dependências básicas...${NC}"
$PIP_CMD install cmake -q || true

echo -e "${YELLOW}[*] Instalando dlib (isso pode levar 5-10 minutos)...${NC}"
$PIP_CMD install dlib==19.24.2 || {
    echo -e "${RED}[✗] Erro ao instalar dlib${NC}"
    echo -e "${YELLOW}[*] Tentando alternativa: usar versão OpenCV${NC}"
    echo ""
    echo "Opções:"
    echo "1. Usar app_opencv.py (sem face_recognition)"
    echo "2. Instalar dependências do sistema e tentar novamente"
    echo ""
    echo "Para opção 1, edite ecosystem.config.js e mude para:"
    echo "  args: 'app_opencv:app --host 0.0.0.0 --port 9090'"
    echo ""
    echo "Para opção 2, execute:"
    echo "  sudo apt install -y cmake libopenblas-dev liblapack-dev"
    echo "  pip install dlib==19.24.2"
    exit 1
}

echo -e "${YELLOW}[*] Instalando face_recognition...${NC}"
$PIP_CMD install face-recognition==1.3.0

echo -e "${YELLOW}[*] Instalando outras dependências...${NC}"
$PIP_CMD install -r requirements.txt -q

echo ""
echo -e "${GREEN}[✓] Dependências instaladas com sucesso!${NC}"
echo ""
echo "Agora reinicie o serviço:"
echo "  pm2 restart face-recognition-service"

