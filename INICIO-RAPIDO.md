# 🚀 Início Rápido - Serviço de Reconhecimento Facial

## Instalação Rápida (OpenCV - Sem dlib)

Esta versão **NÃO requer dlib ou CMake** e funciona em Windows, Linux e macOS.

### 1. Instalar dependências

```bash
cd face-recognition-service
pip install -r requirements-simple.txt
```

### 2. Configurar

```bash
# Copiar arquivo de exemplo
cp .env.example .env

# Editar .env com suas credenciais do Nextcloud
```

### 3. Executar

```bash
python app_opencv.py
```

O serviço estará rodando em: `http://localhost:9090`

### 4. Configurar Next.js

Adicionar no `.env` do projeto Next.js:
```env
FACE_RECOGNITION_API_URL=http://localhost:9090
```

## ✅ Pronto!

Agora você pode testar o reconhecimento facial. O serviço usa OpenCV com:
- Detecção de faces (Haar Cascade)
- Comparação de histogramas
- Template matching

**Não requer:** dlib, CMake, ou compilação de código C++

