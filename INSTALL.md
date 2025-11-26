# Instalação do Serviço de Reconhecimento Facial

## Pré-requisitos

- Python 3.8 ou superior
- pip (gerenciador de pacotes Python)

## Passo 1: Instalar dependências

### Opção 1: OpenCV (Recomendado - Mais Simples)

**Windows/Linux/macOS:**
```bash
cd face-recognition-service
pip install -r requirements-simple.txt
```

Esta versão usa apenas OpenCV e não requer dlib ou CMake. Use `app_opencv.py`:
```bash
python app_opencv.py
```

### Opção 2: face_recognition (Requer dlib)

**Windows:**
```bash
cd face-recognition-service
pip install -r requirements-windows.txt
```

**Nota:** Se `dlib-binary` falhar, você precisará instalar CMake:
1. Baixar de https://cmake.org/download/
2. Durante instalação, marcar "Add CMake to system PATH"
3. Reiniciar terminal e tentar novamente

### Linux/macOS

```bash
cd face-recognition-service
pip install -r requirements.txt
```

**Nota:** Se tiver problemas com `dlib` no Linux/macOS, instale as dependências do sistema primeiro:

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install cmake
sudo apt-get install libopenblas-dev liblapack-dev
pip install -r requirements.txt
```

**macOS:**
```bash
brew install cmake
brew install dlib
pip install -r requirements.txt
```

## Passo 2: Configurar variáveis de ambiente

1. Copiar o arquivo de exemplo:
```bash
cp .env.example .env
```

2. Editar o arquivo `.env` com suas credenciais:
```env
NEXTCLOUD_WEBDAV_URL=http://192.168.15.10/remote.php/dav/files/Ponto
NEXTCLOUD_USER=seu_usuario
NEXTCLOUD_PASSWORD=sua_senha

FACE_MATCH_THRESHOLD=0.6
API_PORT=8000
API_HOST=0.0.0.0
```

## Passo 3: Executar o serviço

```bash
python app.py
```

Ou usando uvicorn diretamente:
```bash
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

O serviço estará disponível em: `http://localhost:8000`

## Passo 4: Configurar Next.js

Adicionar no arquivo `.env` do projeto Next.js:
```env
FACE_RECOGNITION_API_URL=http://localhost:8000
```

## Testar

Acesse `http://localhost:8000` no navegador. Deve retornar:
```json
{
  "status": "ok",
  "service": "face-recognition"
}
```

## Troubleshooting

### Erro ao instalar dlib/face_recognition

**Windows:**
- Instalar Visual C++ Build Tools
- Ou usar: `pip install dlib-binary`

**Linux:**
```bash
sudo apt-get install cmake
sudo apt-get install libopenblas-dev liblapack-dev
```

**macOS:**
```bash
brew install cmake
brew install dlib
```

### Erro de conexão com Nextcloud

- Verificar se as credenciais estão corretas no `.env`
- Verificar se o Nextcloud está acessível na rede
- Testar acesso manual ao WebDAV

