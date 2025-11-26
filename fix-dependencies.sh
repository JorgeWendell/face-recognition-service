#!/bin/bash

# Script para corrigir dependências faltantes

set -e

APP_DIR="/var/www/face-recognition-service"
VENV_DIR="$APP_DIR/venv"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Corrigindo dependências...${NC}"
echo ""

cd $APP_DIR

if [ ! -d "$VENV_DIR" ]; then
    echo -e "${RED}[✗] Ambiente virtual não encontrado!${NC}"
    exit 1
fi

source $VENV_DIR/bin/activate

# Verificar qual app está sendo usado
if grep -q "app:app" ecosystem.config.js 2>/dev/null || [ -f "app.py" ]; then
    echo -e "${YELLOW}[*] Detectado: app.py (requer face_recognition)${NC}"
    
    # Verificar se face_recognition está instalado
    if ! python -c "import face_recognition" 2>/dev/null; then
        echo -e "${YELLOW}[*] face_recognition não encontrado. Instalando...${NC}"
        echo -e "${YELLOW}    Isso pode levar 5-10 minutos (compilação do dlib)...${NC}"
        
        # Instalar cmake se necessário
        pip install cmake -q || true
        
        # Tentar instalar dlib
        echo -e "${YELLOW}[*] Instalando dlib...${NC}"
        pip install dlib==19.24.2 || {
            echo -e "${RED}[✗] Erro ao instalar dlib${NC}"
            echo ""
            echo -e "${YELLOW}Opções:${NC}"
            echo "1. Instalar dependências do sistema e tentar novamente:"
            echo "   sudo apt install -y cmake libopenblas-dev liblapack-dev"
            echo "   pip install dlib==19.24.2"
            echo ""
            echo "2. Usar versão OpenCV (mais fácil):"
            echo "   Edite ecosystem.config.js e mude para app_opencv:app"
            echo "   pip install -r requirements-simple.txt"
            exit 1
        }
        
        # Instalar face_recognition
        echo -e "${YELLOW}[*] Instalando face_recognition...${NC}"
        pip install face-recognition==1.3.0
        
        echo -e "${GREEN}[✓] face_recognition instalado!${NC}"
    else
        echo -e "${GREEN}[✓] face_recognition já está instalado${NC}"
    fi
else
    echo -e "${YELLOW}[*] Detectado: app_opencv.py (não requer face_recognition)${NC}"
    echo -e "${YELLOW}[*] Instalando dependências simples...${NC}"
    pip install -r requirements-simple.txt -q
fi

# Instalar outras dependências que possam estar faltando
echo -e "${YELLOW}[*] Verificando outras dependências...${NC}"
pip install fastapi uvicorn[standard] python-multipart opencv-python numpy Pillow requests pydantic python-dotenv -q

echo ""
echo -e "${GREEN}[✓] Dependências corrigidas!${NC}"
echo ""
echo "Reinicie o serviço:"
echo "  pm2 restart face-recognition-service"

