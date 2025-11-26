#!/bin/bash

# Script de Diagnóstico - Face Recognition Service

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

APP_DIR="/var/www/face-recognition-service"
VENV_DIR="$APP_DIR/venv"
SERVICE_NAME="face-recognition-service"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Diagnóstico - Face Recognition Service${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Verificar se o diretório existe
echo -e "${YELLOW}[1] Verificando diretório...${NC}"
if [ -d "$APP_DIR" ]; then
    echo -e "${GREEN}[✓] Diretório existe: $APP_DIR${NC}"
    cd $APP_DIR
else
    echo -e "${RED}[✗] Diretório não existe: $APP_DIR${NC}"
    exit 1
fi

# Verificar arquivos principais
echo -e "${YELLOW}[2] Verificando arquivos principais...${NC}"
if [ -f "app.py" ]; then
    echo -e "${GREEN}[✓] app.py encontrado${NC}"
else
    echo -e "${RED}[✗] app.py não encontrado${NC}"
fi

if [ -f "app_opencv.py" ]; then
    echo -e "${GREEN}[✓] app_opencv.py encontrado${NC}"
else
    echo -e "${RED}[✗] app_opencv.py não encontrado${NC}"
fi

if [ -f ".env" ]; then
    echo -e "${GREEN}[✓] .env encontrado${NC}"
else
    echo -e "${RED}[✗] .env não encontrado${NC}"
    echo -e "${YELLOW}   Execute: sudo ./setup-env.sh${NC}"
fi

# Verificar ambiente virtual
echo -e "${YELLOW}[3] Verificando ambiente virtual...${NC}"
if [ -d "$VENV_DIR" ]; then
    echo -e "${GREEN}[✓] Ambiente virtual existe${NC}"
    if [ -f "$VENV_DIR/bin/uvicorn" ]; then
        echo -e "${GREEN}[✓] uvicorn instalado${NC}"
    else
        echo -e "${RED}[✗] uvicorn não encontrado no venv${NC}"
    fi
else
    echo -e "${RED}[✗] Ambiente virtual não existe${NC}"
fi

# Verificar PM2
echo -e "${YELLOW}[4] Verificando PM2...${NC}"
if command -v pm2 &> /dev/null; then
    echo -e "${GREEN}[✓] PM2 instalado${NC}"
    echo ""
    echo -e "${YELLOW}Status do PM2:${NC}"
    pm2 status
    echo ""
    echo -e "${YELLOW}Logs do serviço:${NC}"
    pm2 logs $SERVICE_NAME --lines 20 --nostream || echo "Nenhum log disponível"
else
    echo -e "${RED}[✗] PM2 não está instalado${NC}"
fi

# Verificar porta
echo -e "${YELLOW}[5] Verificando porta 9090...${NC}"
if lsof -i :9090 &> /dev/null || netstat -tulpn 2>/dev/null | grep :9090 &> /dev/null; then
    echo -e "${GREEN}[✓] Porta 9090 está em uso${NC}"
    echo -e "${YELLOW}Processo usando a porta:${NC}"
    lsof -i :9090 2>/dev/null || netstat -tulpn 2>/dev/null | grep :9090
else
    echo -e "${RED}[✗] Porta 9090 não está em uso${NC}"
    echo -e "${YELLOW}   O serviço não está rodando na porta 9090${NC}"
fi

# Verificar arquivo .env
echo -e "${YELLOW}[6] Verificando configuração .env...${NC}"
if [ -f ".env" ]; then
    echo -e "${GREEN}Conteúdo do .env:${NC}"
    grep -v "PASSWORD" .env | grep -v "password" || cat .env
    echo ""
    
    API_PORT=$(grep "^API_PORT=" .env 2>/dev/null | cut -d '=' -f2 || echo "")
    if [ -z "$API_PORT" ]; then
        echo -e "${RED}[✗] API_PORT não configurado no .env${NC}"
    else
        echo -e "${GREEN}[✓] API_PORT=$API_PORT${NC}"
    fi
else
    echo -e "${RED}[✗] Arquivo .env não existe${NC}"
fi

# Testar conexão
echo -e "${YELLOW}[7] Testando conexão...${NC}"
if curl -s http://localhost:9090/docs > /dev/null 2>&1; then
    echo -e "${GREEN}[✓] Serviço respondendo em http://localhost:9090${NC}"
else
    echo -e "${RED}[✗] Serviço não está respondendo${NC}"
    echo ""
    echo -e "${YELLOW}Tentando iniciar manualmente para teste...${NC}"
    if [ -d "$VENV_DIR" ]; then
        source $VENV_DIR/bin/activate
        echo -e "${YELLOW}Testando se uvicorn funciona:${NC}"
        $VENV_DIR/bin/uvicorn --version || echo "Erro ao executar uvicorn"
    fi
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}Próximos passos:${NC}"
echo "1. Verifique os logs: pm2 logs $SERVICE_NAME"
echo "2. Reinicie o serviço: pm2 restart $SERVICE_NAME"
echo "3. Verifique o .env: cat $APP_DIR/.env"
echo "4. Teste manualmente: source venv/bin/activate && uvicorn app:app --host 0.0.0.0 --port 9090"
echo ""

