#!/bin/bash

# Script de Deploy Automatizado - Face Recognition Service
# Ubuntu 24.04

set -e  # Parar em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variáveis de configuração
APP_DIR="/var/www/face-recognition-service"
APP_USER="www-data"
SERVICE_NAME="face-recognition-service"
PYTHON_VERSION="python3"
VENV_DIR="$APP_DIR/venv"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deploy Automatizado - Face Recognition${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Por favor, execute como root ou com sudo${NC}"
    exit 1
fi

# Função para imprimir mensagens
print_step() {
    echo -e "${YELLOW}[*] $1${NC}"
}

print_success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

print_error() {
    echo -e "${RED}[✗] $1${NC}"
}

# Passo 1: Atualizar sistema
print_step "Atualizando sistema..."
apt update -qq
apt upgrade -y -qq
print_success "Sistema atualizado"

# Passo 2: Instalar dependências do sistema
print_step "Instalando dependências do sistema..."
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    cmake \
    build-essential \
    libopenblas-dev \
    liblapack-dev \
    libatlas-base-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libv4l-dev \
    libxvidcore-dev \
    libx264-dev \
    nginx \
    ufw \
    > /dev/null 2>&1

print_success "Dependências instaladas"

# Passo 3: Verificar se o diretório já existe
if [ -d "$APP_DIR" ]; then
    print_step "Diretório $APP_DIR já existe. Atualizando..."
    cd $APP_DIR
    if [ -d ".git" ]; then
        git pull origin main || true
    fi
else
    print_step "Criando diretório $APP_DIR..."
    mkdir -p $APP_DIR
    cd $APP_DIR
    
    # Se não houver .git, perguntar sobre o repositório
    if [ ! -d ".git" ]; then
        echo -e "${YELLOW}Diretório não é um repositório Git.${NC}"
        read -p "Digite a URL do repositório GitHub (ou Enter para pular): " REPO_URL
        if [ ! -z "$REPO_URL" ]; then
            print_step "Clonando repositório..."
            git clone $REPO_URL .
        else
            print_step "Criando estrutura básica..."
            # Criar estrutura mínima se não houver repositório
        fi
    fi
fi

# Passo 4: Criar ambiente virtual
print_step "Configurando ambiente virtual Python..."
if [ ! -d "$VENV_DIR" ]; then
    $PYTHON_VERSION -m venv $VENV_DIR
    print_success "Ambiente virtual criado"
else
    print_success "Ambiente virtual já existe"
fi

# Ativar ambiente virtual e atualizar pip
source $VENV_DIR/bin/activate
pip install --upgrade pip -q

# Passo 5: Instalar dependências Python
print_step "Instalando dependências Python..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt -q
    print_success "Dependências instaladas (requirements.txt)"
elif [ -f "requirements-simple.txt" ]; then
    pip install -r requirements-simple.txt -q
    print_success "Dependências instaladas (requirements-simple.txt)"
else
    print_error "Arquivo requirements.txt não encontrado!"
    exit 1
fi

# Passo 6: Configurar arquivo .env
print_step "Configurando variáveis de ambiente..."
if [ ! -f "$APP_DIR/.env" ]; then
    if [ -f "$APP_DIR/.env.example" ]; then
        cp $APP_DIR/.env.example $APP_DIR/.env
        print_success "Arquivo .env criado a partir do .env.example"
        echo -e "${YELLOW}⚠ IMPORTANTE: Edite o arquivo .env com suas credenciais!${NC}"
        echo -e "${YELLOW}   nano $APP_DIR/.env${NC}"
    else
        print_error ".env.example não encontrado!"
        exit 1
    fi
else
    print_success "Arquivo .env já existe"
fi

# Passo 7: Criar diretório de logs
print_step "Criando diretório de logs..."
mkdir -p $APP_DIR/logs
chown -R $APP_USER:$APP_USER $APP_DIR
print_success "Diretório de logs criado"

# Passo 8: Instalar PM2 (se não estiver instalado)
print_step "Verificando PM2..."
if ! command -v pm2 &> /dev/null; then
    print_step "Instalando PM2..."
    npm install -g pm2 -q
    print_success "PM2 instalado"
else
    print_success "PM2 já está instalado"
fi

# Passo 9: Configurar PM2
print_step "Configurando PM2..."
cd $APP_DIR

# Atualizar ecosystem.config.js com o caminho correto
if [ -f "ecosystem.config.js" ]; then
    # Substituir caminho no ecosystem.config.js
    sed -i "s|/var/www/face-recognition-service|$APP_DIR|g" ecosystem.config.js
    print_success "ecosystem.config.js configurado"
fi

# Parar serviço existente se estiver rodando
pm2 delete $SERVICE_NAME 2>/dev/null || true

# Iniciar com PM2
if [ -f "ecosystem.config.js" ]; then
    pm2 start ecosystem.config.js
else
    # Iniciar manualmente se não houver ecosystem.config.js
    pm2 start $VENV_DIR/bin/uvicorn --name $SERVICE_NAME -- \
        app:app --host 0.0.0.0 --port 9090
fi

pm2 save
print_success "Serviço iniciado com PM2"

# Configurar PM2 para iniciar no boot
print_step "Configurando PM2 para iniciar no boot..."
pm2 startup systemd -u $USER --hp /home/$USER | grep "sudo" | bash || true
print_success "PM2 configurado para iniciar no boot"

# Passo 10: Configurar firewall
print_step "Configurando firewall..."
ufw --force enable > /dev/null 2>&1 || true
ufw allow 22/tcp > /dev/null 2>&1  # SSH
ufw allow 80/tcp > /dev/null 2>&1  # HTTP
ufw allow 443/tcp > /dev/null 2>&1 # HTTPS
ufw allow 9090/tcp > /dev/null 2>&1 # API (temporário, remover depois do Nginx)
print_success "Firewall configurado"

# Passo 11: Verificar status
print_step "Verificando status do serviço..."
sleep 2
pm2 status

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deploy Concluído!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Próximos passos:${NC}"
echo "1. Edite o arquivo .env com suas credenciais:"
echo "   ${YELLOW}sudo nano $APP_DIR/.env${NC}"
echo ""
echo "2. Reinicie o serviço após editar o .env:"
echo "   ${YELLOW}pm2 restart $SERVICE_NAME${NC}"
echo ""
echo "3. Verifique os logs:"
echo "   ${YELLOW}pm2 logs $SERVICE_NAME${NC}"
echo ""
echo "4. Teste a API:"
echo "   ${YELLOW}curl http://localhost:9090/docs${NC}"
echo ""
echo -e "${GREEN}Serviço rodando em: http://$(hostname -I | awk '{print $1}'):9090${NC}"
echo ""

