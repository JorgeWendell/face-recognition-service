#!/bin/bash

# Script específico para instalar dlib no ambiente virtual

set -e

APP_DIR="/var/www/face-recognition-service"
VENV_DIR="$APP_DIR/venv"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Instalando dlib no ambiente virtual...${NC}"
echo ""

cd $APP_DIR

# Verificar se venv existe
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${RED}[✗] Ambiente virtual não encontrado!${NC}"
    echo -e "${YELLOW}[*] Criando ambiente virtual...${NC}"
    python3 -m venv $VENV_DIR
fi

# Usar pip do venv diretamente (não precisa ativar)
PIP_CMD="$VENV_DIR/bin/pip"
PYTHON_CMD="$VENV_DIR/bin/python"

echo -e "${YELLOW}[*] Verificando ambiente virtual...${NC}"
echo "Pip: $PIP_CMD"
echo "Python: $PYTHON_CMD"

# Verificar se pip existe
if [ ! -f "$PIP_CMD" ]; then
    echo -e "${RED}[✗] pip não encontrado no venv!${NC}"
    exit 1
fi

# Atualizar pip
echo -e "${YELLOW}[*] Atualizando pip...${NC}"
$PIP_CMD install --upgrade pip -q

# Instalar cmake
echo -e "${YELLOW}[*] Instalando cmake...${NC}"
$PIP_CMD install cmake -q || true

# Verificar dependências do sistema
echo -e "${YELLOW}[*] Verificando dependências do sistema...${NC}"
MISSING_DEPS=()

if ! dpkg -l | grep -q "^ii.*cmake"; then
    MISSING_DEPS+=("cmake")
fi
if ! dpkg -l | grep -q "^ii.*libopenblas-dev"; then
    MISSING_DEPS+=("libopenblas-dev")
fi
if ! dpkg -l | grep -q "^ii.*liblapack-dev"; then
    MISSING_DEPS+=("liblapack-dev")
fi
if ! dpkg -l | grep -q "^ii.*libx11-dev"; then
    MISSING_DEPS+=("libx11-dev")
fi
if ! dpkg -l | grep -q "^ii.*libgtk-3-dev"; then
    MISSING_DEPS+=("libgtk-3-dev")
fi
if ! dpkg -l | grep -q "^ii.*python3-dev"; then
    MISSING_DEPS+=("python3-dev")
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo -e "${YELLOW}[!] Dependências do sistema faltando: ${MISSING_DEPS[*]}${NC}"
    echo -e "${YELLOW}[*] Instalando dependências do sistema...${NC}"
    sudo apt install -y ${MISSING_DEPS[@]}
fi

# Instalar dlib (pode levar 5-10 minutos)
echo -e "${YELLOW}[*] Instalando dlib (isso pode levar 5-10 minutos)...${NC}"
echo -e "${YELLOW}    Por favor, aguarde...${NC}"

if $PIP_CMD install dlib==19.24.2; then
    echo -e "${GREEN}[✓] dlib instalado com sucesso!${NC}"
    
    # Instalar face_recognition
    echo -e "${YELLOW}[*] Instalando face_recognition...${NC}"
    $PIP_CMD install face-recognition==1.3.0
    
    echo -e "${GREEN}[✓] face_recognition instalado!${NC}"
    echo ""
    echo -e "${GREEN}[✓] Tudo pronto! Reinicie o serviço:${NC}"
    echo "  pm2 restart face-recognition-service"
else
    echo -e "${RED}[✗] Erro ao instalar dlib${NC}"
    echo ""
    echo -e "${YELLOW}Alternativa: Use a versão OpenCV${NC}"
    echo "1. Edite ecosystem.config.js:"
    echo "   nano ecosystem.config.js"
    echo "   Mude: args: 'app_opencv:app --host 0.0.0.0 --port 9090'"
    echo ""
    echo "2. Instale dependências simples:"
    echo "   $PIP_CMD install -r requirements-simple.txt"
    echo ""
    echo "3. Reinicie:"
    echo "   pm2 restart face-recognition-service"
    exit 1
fi

