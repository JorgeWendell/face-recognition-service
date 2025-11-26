#!/bin/bash

# Script para corrigir e reiniciar o serviço PM2

set -e

APP_DIR="/var/www/face-recognition-service"
VENV_DIR="$APP_DIR/venv"
SERVICE_NAME="face-recognition-service"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Corrigindo configuração do PM2...${NC}"
echo ""

cd $APP_DIR

# Parar serviço se estiver rodando
echo -e "${YELLOW}[*] Parando serviço existente...${NC}"
pm2 delete $SERVICE_NAME 2>/dev/null || true

# Atualizar ecosystem.config.js com caminho correto do venv
if [ -f "ecosystem.config.js" ]; then
    echo -e "${YELLOW}[*] Atualizando ecosystem.config.js...${NC}"
    sed -i "s|venv/bin/uvicorn|$VENV_DIR/bin/uvicorn|g" ecosystem.config.js
    sed -i "s|/var/www/face-recognition-service|$APP_DIR|g" ecosystem.config.js
fi

# Verificar se venv existe
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${RED}[✗] Ambiente virtual não encontrado em $VENV_DIR${NC}"
    exit 1
fi

# Verificar se uvicorn está instalado
if [ ! -f "$VENV_DIR/bin/uvicorn" ]; then
    echo -e "${RED}[✗] uvicorn não encontrado no venv${NC}"
    echo -e "${YELLOW}[*] Instalando dependências básicas...${NC}"
    source $VENV_DIR/bin/activate
    pip install --upgrade pip -q
    pip install fastapi uvicorn[standard] -q
fi

# Verificar se face_recognition está instalado (se usar app.py)
if [ -f "app.py" ] && grep -q "import face_recognition" app.py 2>/dev/null; then
    source $VENV_DIR/bin/activate
    if ! python -c "import face_recognition" 2>/dev/null; then
        echo -e "${YELLOW}[*] face_recognition não encontrado. Instalando...${NC}"
        echo -e "${YELLOW}    Isso pode levar alguns minutos...${NC}"
        pip install cmake -q || true
        pip install dlib==19.24.2 || {
            echo -e "${RED}[✗] Erro ao instalar dlib${NC}"
            echo -e "${YELLOW}[*] Alternativa: usar app_opencv.py${NC}"
            echo ""
            echo "Edite ecosystem.config.js e mude para:"
            echo "  args: 'app_opencv:app --host 0.0.0.0 --port 9090'"
            echo ""
            echo "Ou execute: ./install-deps.sh"
            exit 1
        }
        pip install face-recognition==1.3.0
    fi
fi

# Iniciar com PM2
echo -e "${YELLOW}[*] Iniciando serviço com PM2...${NC}"
if [ -f "ecosystem.config.js" ]; then
    pm2 start ecosystem.config.js
else
    # Fallback: iniciar manualmente
    pm2 start $VENV_DIR/bin/uvicorn --name $SERVICE_NAME --interpreter none -- \
        app:app --host 0.0.0.0 --port 9090
fi

pm2 save

echo ""
echo -e "${GREEN}[✓] Serviço reiniciado!${NC}"
echo ""
echo -e "${YELLOW}Status:${NC}"
pm2 status

echo ""
echo -e "${YELLOW}Logs (últimas 20 linhas):${NC}"
pm2 logs $SERVICE_NAME --lines 20 --nostream

echo ""
echo -e "${YELLOW}Teste a API:${NC}"
echo "curl http://localhost:9090/docs"
echo ""

