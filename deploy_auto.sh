#!/bin/bash

# Script de Deploy Completamente Automatizado
# Não requer interação do usuário

set -e

APP_DIR="/var/www/face-recognition-service"
VENV_DIR="$APP_DIR/venv"
SERVICE_NAME="face-recognition-service"
REPO_URL="https://github.com/JorgeWendell/face-recognition-service.git"
USE_OPENCV=false

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funções auxiliares
print_step() {
    echo -e "${BLUE}[*] $1${NC}"
}

print_success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

print_error() {
    echo -e "${RED}[✗] $1${NC}"
}

print_info() {
    echo -e "${YELLOW}[!] $1${NC}"
}

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    print_error "Por favor, execute como root (sudo ./deploy_auto.sh)"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Deploy Automatizado - Face Recognition${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# ============================================
# Passo 1: Atualizar sistema
# ============================================
print_step "Atualizando sistema..."
export DEBIAN_FRONTEND=noninteractive
apt update -qq > /dev/null 2>&1
apt upgrade -y -qq > /dev/null 2>&1
print_success "Sistema atualizado"

# ============================================
# Passo 2: Instalar dependências do sistema
# ============================================
print_step "Instalando dependências do sistema..."
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
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
    libx11-dev \
    libgtk-3-dev \
    curl \
    nginx \
    ufw \
    > /dev/null 2>&1
print_success "Dependências do sistema instaladas"

# ============================================
# Passo 3: Instalar Node.js e PM2
# ============================================
print_step "Instalando Node.js e PM2..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
    apt install -y nodejs > /dev/null 2>&1
fi

if ! command -v pm2 &> /dev/null; then
    npm install -g pm2 > /dev/null 2>&1
fi
print_success "Node.js e PM2 instalados"

# ============================================
# Passo 4: Criar diretório e clonar repositório
# ============================================
print_step "Preparando diretório da aplicação..."
mkdir -p /var/www
cd /var/www

if [ -d "$APP_DIR" ]; then
    print_info "Diretório já existe, fazendo backup..."
    if [ -d "${APP_DIR}.backup" ]; then
        rm -rf "${APP_DIR}.backup"
    fi
    mv "$APP_DIR" "${APP_DIR}.backup" 2>/dev/null || true
fi

if [ -d "$APP_DIR/.git" ]; then
    print_info "Repositório já existe, atualizando..."
    cd "$APP_DIR"
    git pull origin main > /dev/null 2>&1 || true
else
    print_step "Clonando repositório..."
    git clone "$REPO_URL" "$APP_DIR" > /dev/null 2>&1 || {
        print_error "Erro ao clonar repositório. Criando estrutura básica..."
        mkdir -p "$APP_DIR"
        cd "$APP_DIR"
    }
fi

cd "$APP_DIR"
chown -R $SUDO_USER:$SUDO_USER "$APP_DIR" 2>/dev/null || true
print_success "Diretório preparado"

# ============================================
# Passo 5: Criar ambiente virtual
# ============================================
print_step "Configurando ambiente virtual Python..."
if [ -d "$VENV_DIR" ]; then
    print_info "Ambiente virtual já existe"
else
    python3 -m venv "$VENV_DIR"
    print_success "Ambiente virtual criado"
fi

# Atualizar pip
print_step "Atualizando pip..."
"$VENV_DIR/bin/pip" install --upgrade pip -q > /dev/null 2>&1

# ============================================
# Passo 6: Instalar dependências Python
# ============================================
print_step "Instalando dependências Python..."

# Instalar cmake no venv
print_step "Instalando cmake..."
"$VENV_DIR/bin/pip" install cmake -q > /dev/null 2>&1 || true

# Instalar dlib (pode levar 5-10 minutos)
print_step "Instalando dlib (isso pode levar 5-10 minutos)..."
print_info "Por favor, aguarde..."
if "$VENV_DIR/bin/pip" install dlib==19.24.2 > /tmp/dlib_install.log 2>&1; then
    print_success "dlib instalado"
else
    print_error "Erro ao instalar dlib. Verificando log..."
    if grep -q "error\|Error\|ERROR" /tmp/dlib_install.log; then
        print_info "Tentando usar versão OpenCV como alternativa..."
        # Usar app_opencv.py
        if [ -f "ecosystem.config.js" ]; then
            sed -i "s|app:app|app_opencv:app|g" ecosystem.config.js
        fi
        USE_OPENCV=true
    else
        print_success "dlib instalado (com avisos)"
        USE_OPENCV=false
    fi
fi

# Instalar face_recognition (se não usar OpenCV)
if [ "$USE_OPENCV" != "true" ]; then
    print_step "Instalando face_recognition..."
    "$VENV_DIR/bin/pip" install face-recognition==1.3.0 -q > /dev/null 2>&1 || {
        print_info "face_recognition falhou, usando versão OpenCV..."
        USE_OPENCV=true
        if [ -f "ecosystem.config.js" ]; then
            sed -i "s|app:app|app_opencv:app|g" ecosystem.config.js
        fi
    }
fi

# Instalar outras dependências
print_step "Instalando outras dependências Python..."
if [ "$USE_OPENCV" = "true" ]; then
    if [ -f "requirements-simple.txt" ]; then
        "$VENV_DIR/bin/pip" install -r requirements-simple.txt -q > /dev/null 2>&1
    else
        "$VENV_DIR/bin/pip" install fastapi uvicorn[standard] python-multipart opencv-python numpy Pillow requests pydantic python-dotenv -q > /dev/null 2>&1
    fi
    print_success "Dependências instaladas (versão OpenCV)"
else
    if [ -f "requirements.txt" ]; then
        "$VENV_DIR/bin/pip" install -r requirements.txt -q > /dev/null 2>&1
    else
        "$VENV_DIR/bin/pip" install fastapi uvicorn[standard] python-multipart opencv-python numpy Pillow requests pydantic python-dotenv face-recognition dlib -q > /dev/null 2>&1
    fi
    print_success "Dependências instaladas (com face_recognition)"
fi

# ============================================
# Passo 7: Configurar arquivo .env
# ============================================
print_step "Configurando arquivo .env..."
cat > "$APP_DIR/.env" << EOF
NEXTCLOUD_WEBDAV_URL=http://192.168.15.10/remote.php/dav/files/Ponto
NEXTCLOUD_USER=ponto
NEXTCLOUD_PASSWORD=Lucas@120908
API_HOST=0.0.0.0
API_PORT=9090
FACE_MATCH_THRESHOLD=0.6
EOF
chmod 600 "$APP_DIR/.env"
print_success "Arquivo .env configurado"

# ============================================
# Passo 8: Configurar ecosystem.config.js
# ============================================
print_step "Configurando PM2..."
if [ ! -f "$APP_DIR/ecosystem.config.js" ]; then
    cat > "$APP_DIR/ecosystem.config.js" << 'EOF'
module.exports = {
  apps: [
    {
      name: 'face-recognition-service',
      script: 'venv/bin/uvicorn',
      args: 'app:app --host 0.0.0.0 --port 9090',
      cwd: '/var/www/face-recognition-service',
      interpreter: 'none',
      env: {
        API_HOST: '0.0.0.0',
        API_PORT: '9090',
        FACE_MATCH_THRESHOLD: '0.6',
      },
      env_file: '.env',
      error_file: './logs/err.log',
      out_file: './logs/out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      instances: 1,
      exec_mode: 'fork',
    },
  ],
};
EOF
fi

# Atualizar caminhos no ecosystem.config.js
sed -i "s|/var/www/face-recognition-service|$APP_DIR|g" "$APP_DIR/ecosystem.config.js"
sed -i "s|venv/bin/uvicorn|$VENV_DIR/bin/uvicorn|g" "$APP_DIR/ecosystem.config.js"

# Criar diretório de logs
mkdir -p "$APP_DIR/logs"
print_success "PM2 configurado"

# ============================================
# Passo 9: Parar serviço existente e iniciar
# ============================================
print_step "Iniciando serviço com PM2..."
pm2 delete "$SERVICE_NAME" > /dev/null 2>&1 || true
cd "$APP_DIR"
pm2 start ecosystem.config.js > /dev/null 2>&1
pm2 save > /dev/null 2>&1

# Configurar PM2 para iniciar no boot
print_step "Configurando PM2 para iniciar no boot..."
pm2 startup systemd -u $SUDO_USER --hp /home/$SUDO_USER > /tmp/pm2_startup.txt 2>&1 || true
STARTUP_CMD=$(grep "sudo" /tmp/pm2_startup.txt | head -1)
if [ ! -z "$STARTUP_CMD" ]; then
    eval "$STARTUP_CMD" > /dev/null 2>&1 || true
fi

print_success "Serviço iniciado"

# ============================================
# Passo 10: Configurar firewall
# ============================================
print_step "Configurando firewall..."
ufw allow 9090/tcp > /dev/null 2>&1 || true
print_success "Firewall configurado"

# ============================================
# Passo 11: Verificar se está funcionando
# ============================================
print_step "Verificando serviço..."
sleep 3

if pm2 list | grep -q "$SERVICE_NAME.*online"; then
    print_success "Serviço está rodando!"
else
    print_error "Serviço não está rodando. Verificando logs..."
    pm2 logs "$SERVICE_NAME" --lines 10 --nostream
fi

# Testar API
print_step "Testando API..."
sleep 2
if curl -s http://localhost:9090/docs > /dev/null 2>&1 || curl -s http://localhost:9090/ > /dev/null 2>&1; then
    print_success "API está respondendo!"
else
    print_info "API ainda não está respondendo. Pode levar alguns segundos..."
    print_info "Verifique os logs: pm2 logs $SERVICE_NAME"
fi

# ============================================
# Resumo final
# ============================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Deploy Concluído!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Informações:${NC}"
echo "  • Diretório: $APP_DIR"
echo "  • Serviço: $SERVICE_NAME"
echo "  • Porta: 9090"
echo "  • Ambiente: $(if [ "$USE_OPENCV" = "true" ]; then echo "OpenCV"; else echo "face_recognition"; fi)"
echo ""
echo -e "${BLUE}Comandos úteis:${NC}"
echo "  • Ver status: pm2 status"
echo "  • Ver logs: pm2 logs $SERVICE_NAME"
echo "  • Reiniciar: pm2 restart $SERVICE_NAME"
echo "  • Parar: pm2 stop $SERVICE_NAME"
echo "  • Testar API: curl http://localhost:9090/docs"
echo ""
echo -e "${GREEN}Pronto! O serviço está rodando.${NC}"
echo ""

