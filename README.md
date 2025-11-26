# Serviço de Reconhecimento Facial

Serviço Python para reconhecimento facial usando `face_recognition` ou OpenCV.

## 🚀 Deploy em Produção

### Deploy Automatizado (Recomendado)

```bash
# No servidor Ubuntu, execute:
wget https://raw.githubusercontent.com/seu-usuario/face-recognition-service/main/deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh
```

O script automatiza toda a instalação e configuração!

### Deploy Manual

Para fazer deploy manual ou entender cada passo, consulte o guia completo em [DEPLOY.md](./DEPLOY.md).

## 📦 Instalação Local

### Windows

```bash
pip install -r requirements-windows.txt
```

### Linux/macOS

```bash
pip install -r requirements.txt
```

**Nota:** No Linux, pode ser necessário instalar dependências do sistema:

```bash
sudo apt-get install cmake libopenblas-dev liblapack-dev
```

### Versão OpenCV (sem dlib)

Se tiver problemas com dlib, use a versão que usa apenas OpenCV:

```bash
pip install -r requirements-simple.txt
```

## ⚙️ Configuração

1. Copiar arquivo de exemplo:

```bash
cp .env.example .env
```

2. Editar `.env` com suas credenciais:

- `NEXTCLOUD_WEBDAV_URL`: URL do WebDAV do Nextcloud
- `NEXTCLOUD_USER`: Usuário do Nextcloud
- `NEXTCLOUD_PASSWORD`: Senha do Nextcloud
- `API_HOST`: Host do serviço (padrão: 0.0.0.0)
- `API_PORT`: Porta do serviço (padrão: 9090)
- `FACE_MATCH_THRESHOLD`: Threshold de similaridade (padrão: 0.6)

## ▶️ Executar

### Desenvolvimento

```bash
# Versão com face_recognition
uvicorn app:app --host 0.0.0.0 --port 9090 --reload

# Versão com OpenCV apenas
uvicorn app_opencv:app --host 0.0.0.0 --port 9090 --reload
```

### Produção

Use PM2 ou Systemd conforme descrito em [DEPLOY.md](./DEPLOY.md).

## Endpoints

### POST /recognize-with-collaborators

Reconhece uma face comparando com lista de colaboradores.

**Request:**

```json
{
  "image_base64": "data:image/jpeg;base64,...",
  "latitude": "-23.5505",
  "longitude": "-46.6333",
  "dispositivo_info": "...",
  "colaboradores": [
    {
      "id": "...",
      "nome_completo": "...",
      "foto_url": "..."
    }
  ]
}
```

**Response:**

```json
{
  "success": true,
  "colaborador_id": "...",
  "colaborador_nome": "...",
  "score": 0.85
}
```

## Configuração

Edite o arquivo `.env`:

- `NEXTCLOUD_WEBDAV_URL`: URL do WebDAV do Nextcloud
- `NEXTCLOUD_USER`: Usuário do Nextcloud
- `NEXTCLOUD_PASSWORD`: Senha do Nextcloud
- `FACE_MATCH_THRESHOLD`: Threshold de similaridade (padrão: 0.6)
- `API_PORT`: Porta do serviço (padrão: 9090)
- `API_HOST`: Host do serviço (padrão: 0.0.0.0)
