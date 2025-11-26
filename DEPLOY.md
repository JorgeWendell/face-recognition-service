# Guia de Deploy - Ubuntu 24.04

Este guia explica como fazer o deploy do serviço de reconhecimento facial em um servidor Ubuntu 24.04.

## Pré-requisitos

- Ubuntu 24.04 LTS
- Acesso root ou sudo
- Python 3.10 ou superior
- Git instalado

## Passo 1: Preparar o Servidor

```bash
# Atualizar o sistema
sudo apt update && sudo apt upgrade -y

# Instalar dependências do sistema
sudo apt install -y python3 python3-pip python3-venv git cmake build-essential

# Instalar dependências para dlib e OpenCV
sudo apt install -y libopenblas-dev liblapack-dev libatlas-base-dev
sudo apt install -y libjpeg-dev libpng-dev libtiff-dev
sudo apt install -y libavcodec-dev libavformat-dev libswscale-dev libv4l-dev
sudo apt install -y libxvidcore-dev libx264-dev
```

## Passo 2: Clonar o Repositório

```bash
# Criar diretório para aplicações
sudo mkdir -p /var/www
cd /var/www

# Clonar o repositório (substitua pela URL do seu repositório)
sudo git clone https://github.com/seu-usuario/face-recognition-service.git
sudo chown -R $USER:$USER /var/www/face-recognition-service
cd face-recognition-service
```

## Passo 3: Configurar Ambiente Virtual

```bash
# Criar ambiente virtual
python3 -m venv venv

# Ativar ambiente virtual
source venv/bin/activate

# Atualizar pip
pip install --upgrade pip

# Instalar dependências
pip install -r requirements.txt

# OU se preferir usar apenas OpenCV (sem dlib):
# pip install -r requirements-simple.txt
```

## Passo 4: Configurar Variáveis de Ambiente

```bash
# Copiar arquivo de exemplo
cp .env.example .env

# Editar arquivo .env
nano .env
```

Configure as variáveis:

- `NEXTCLOUD_WEBDAV_URL`: URL do seu Nextcloud
- `NEXTCLOUD_USER`: Usuário do Nextcloud
- `NEXTCLOUD_PASSWORD`: Senha do Nextcloud
- `API_HOST`: 0.0.0.0 (para aceitar conexões externas)
- `API_PORT`: 8000 (ou a porta desejada)
- `FACE_MATCH_THRESHOLD`: 0.6 (threshold de similaridade)

## Passo 5: Testar o Serviço

```bash
# Ativar ambiente virtual
source venv/bin/activate

# Testar o serviço
uvicorn app:app --host 0.0.0.0 --port 8000

# Ou usando o app_opencv.py (versão sem dlib):
# uvicorn app_opencv:app --host 0.0.0.0 --port 8000
```

Acesse `http://seu-servidor:8000/docs` para ver a documentação da API.

## Passo 6: Configurar como Serviço (Escolha uma opção)

### Opção A: Usando PM2 (Recomendado)

```bash
# Instalar PM2 globalmente
sudo npm install -g pm2

# Criar diretório de logs
mkdir -p logs

# Iniciar com PM2
pm2 start ecosystem.config.js

# Salvar configuração do PM2
pm2 save

# Configurar PM2 para iniciar no boot
pm2 startup
# Execute o comando que aparecer (será algo como: sudo env PATH=...)
```

**Comandos úteis do PM2:**

```bash
pm2 status              # Ver status
pm2 logs                # Ver logs
pm2 restart face-recognition-service  # Reiniciar
pm2 stop face-recognition-service      # Parar
pm2 delete face-recognition-service    # Remover
```

### Opção B: Usando Systemd

```bash
# Copiar arquivo de serviço
sudo cp face-recognition.service /etc/systemd/system/

# Recarregar systemd
sudo systemctl daemon-reload

# Habilitar serviço para iniciar no boot
sudo systemctl enable face-recognition.service

# Iniciar serviço
sudo systemctl start face-recognition.service

# Verificar status
sudo systemctl status face-recognition.service
```

**Comandos úteis do Systemd:**

```bash
sudo systemctl start face-recognition.service    # Iniciar
sudo systemctl stop face-recognition.service     # Parar
sudo systemctl restart face-recognition.service  # Reiniciar
sudo systemctl status face-recognition.service   # Status
sudo journalctl -u face-recognition.service -f   # Ver logs
```

## Passo 7: Configurar Firewall

```bash
# Permitir porta 8000 (se necessário)
sudo ufw allow 8000/tcp

# Ou se usar Nginx como proxy reverso, permitir apenas 80/443
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

## Passo 8: Configurar Nginx (Opcional mas Recomendado)

Crie um arquivo de configuração do Nginx:

```bash
sudo nano /etc/nginx/sites-available/face-recognition
```

Conteúdo:

```nginx
server {
    listen 80;
    server_name api-face-recognition.seudominio.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Ativar o site:

```bash
sudo ln -s /etc/nginx/sites-available/face-recognition /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## Passo 9: Configurar SSL com Let's Encrypt (Opcional)

```bash
# Instalar Certbot
sudo apt install certbot python3-certbot-nginx

# Obter certificado SSL
sudo certbot --nginx -d api-face-recognition.seudominio.com
```

## Atualizar o Serviço

```bash
cd /var/www/face-recognition-service
git pull origin main
source venv/bin/activate
pip install -r requirements.txt

# Reiniciar serviço
pm2 restart face-recognition-service
# OU
sudo systemctl restart face-recognition.service
```

## Verificar Logs

**PM2:**

```bash
pm2 logs face-recognition-service
```

**Systemd:**

```bash
sudo journalctl -u face-recognition.service -f
```

## Troubleshooting

### Erro ao instalar dlib

Se tiver problemas com dlib, use a versão OpenCV:

```bash
pip install -r requirements-simple.txt
# E use app_opencv.py ao invés de app.py
```

### Porta já em uso

```bash
# Verificar qual processo está usando a porta
sudo lsof -i :8000
# Ou
sudo netstat -tulpn | grep 8000
```

### Problemas de permissão

```bash
sudo chown -R www-data:www-data /var/www/face-recognition-service
```

## Configuração no Next.js

No seu servidor Next.js, atualize a URL do serviço Python no arquivo de configuração:

```env
FACE_RECOGNITION_API_URL=http://ip-do-servidor-python:8000
```

Ou se usar Nginx com domínio:

```env
FACE_RECOGNITION_API_URL=https://api-face-recognition.seudominio.com
```
