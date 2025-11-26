#!/bin/bash

# Script para configurar o arquivo .env interativamente

set -e

APP_DIR="/var/www/face-recognition-service"
ENV_FILE="$APP_DIR/.env"
ENV_EXAMPLE="$APP_DIR/.env.example"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Configuração do arquivo .env${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

if [ ! -f "$ENV_EXAMPLE" ]; then
    echo "Arquivo .env.example não encontrado!"
    exit 1
fi

# Copiar exemplo se não existir
if [ ! -f "$ENV_FILE" ]; then
    cp $ENV_EXAMPLE $ENV_FILE
    echo "Arquivo .env criado a partir do .env.example"
fi

echo "Por favor, preencha as informações abaixo:"
echo ""

# Ler valores atuais (se existirem)
CURRENT_WEBDAV=$(grep "^NEXTCLOUD_WEBDAV_URL=" $ENV_FILE 2>/dev/null | cut -d '=' -f2 || echo "")
CURRENT_USER=$(grep "^NEXTCLOUD_USER=" $ENV_FILE 2>/dev/null | cut -d '=' -f2 || echo "")
CURRENT_PASS=$(grep "^NEXTCLOUD_PASSWORD=" $ENV_FILE 2>/dev/null | cut -d '=' -f2 || echo "")
CURRENT_PORT=$(grep "^API_PORT=" $ENV_FILE 2>/dev/null | cut -d '=' -f2 || echo "9090")
CURRENT_THRESHOLD=$(grep "^FACE_MATCH_THRESHOLD=" $ENV_FILE 2>/dev/null | cut -d '=' -f2 || echo "0.6")

# Solicitar informações
read -p "URL do WebDAV do Nextcloud [$CURRENT_WEBDAV]: " WEBDAV_URL
WEBDAV_URL=${WEBDAV_URL:-$CURRENT_WEBDAV}

read -p "Usuário do Nextcloud [$CURRENT_USER]: " NEXTCLOUD_USER
NEXTCLOUD_USER=${NEXTCLOUD_USER:-$CURRENT_USER}

read -sp "Senha do Nextcloud: " NEXTCLOUD_PASSWORD
echo ""

read -p "Porta da API [$CURRENT_PORT]: " API_PORT
API_PORT=${API_PORT:-$CURRENT_PORT}

read -p "Threshold de similaridade (0.0-1.0) [$CURRENT_THRESHOLD]: " FACE_MATCH_THRESHOLD
FACE_MATCH_THRESHOLD=${FACE_MATCH_THRESHOLD:-$CURRENT_THRESHOLD}

# Atualizar arquivo .env
cat > $ENV_FILE << EOF
# Configurações do Nextcloud
NEXTCLOUD_WEBDAV_URL=$WEBDAV_URL
NEXTCLOUD_USER=$NEXTCLOUD_USER
NEXTCLOUD_PASSWORD=$NEXTCLOUD_PASSWORD

# Configurações do Serviço
API_HOST=0.0.0.0
API_PORT=$API_PORT

# Threshold de similaridade facial (0.0 a 1.0)
FACE_MATCH_THRESHOLD=$FACE_MATCH_THRESHOLD
EOF

echo ""
echo -e "${GREEN}Arquivo .env configurado com sucesso!${NC}"
echo ""
echo "Para aplicar as mudanças, reinicie o serviço:"
echo -e "${YELLOW}pm2 restart face-recognition-service${NC}"
echo ""

