# Como Enviar para o GitHub

## Passo 1: Criar Repositório no GitHub

1. Acesse https://github.com
2. Clique em "New repository"
3. Nome: `face-recognition-service`
4. Descrição: "Serviço de reconhecimento facial para sistema de ponto"
5. Público ou Privado (sua escolha)
6. **NÃO** inicialize com README, .gitignore ou license
7. Clique em "Create repository"

## Passo 2: Inicializar Git no Diretório

```bash
cd face-recognition-service

# Inicializar repositório Git
git init

# Adicionar todos os arquivos (exceto os ignorados pelo .gitignore)
git add .

# Fazer commit inicial
git commit -m "Initial commit: Face Recognition Service"
```

## Passo 3: Conectar com o Repositório Remoto

```bash
# Adicionar remote (substitua pela URL do seu repositório)
git remote add origin https://github.com/seu-usuario/face-recognition-service.git

# Ou se usar SSH:
# git remote add origin git@github.com:seu-usuario/face-recognition-service.git
```

## Passo 4: Enviar para o GitHub

```bash
# Enviar código para o repositório
git branch -M main
git push -u origin main
```

## Arquivos que Serão Enviados

✅ **Serão enviados:**

- `app.py` - Aplicação principal (com face_recognition)
- `app_opencv.py` - Versão alternativa (apenas OpenCV)
- `requirements.txt` - Dependências principais
- `requirements-simple.txt` - Dependências (sem dlib)
- `requirements-windows.txt` - Dependências para Windows
- `README.md` - Documentação principal
- `DEPLOY.md` - Guia de deploy
- `INSTALL.md` - Guia de instalação
- `INICIO-RAPIDO.md` - Guia rápido
- `.env.example` - Exemplo de variáveis de ambiente
- `.gitignore` - Arquivos ignorados
- `ecosystem.config.js` - Configuração PM2
- `face-recognition.service` - Configuração Systemd

❌ **NÃO serão enviados (devido ao .gitignore):**

- `venv/` - Ambiente virtual
- `.env` - Variáveis de ambiente (sensíveis)
- `__pycache__/` - Cache Python
- `*.log` - Arquivos de log
- `logs/` - Diretório de logs

## Verificar o que será enviado

Antes de fazer push, verifique o que será enviado:

```bash
git status
git ls-files
```

## Atualizações Futuras

Para enviar atualizações:

```bash
git add .
git commit -m "Descrição da alteração"
git push origin main
```

## Clonar no Servidor Ubuntu

Depois de enviar para o GitHub, no servidor Ubuntu:

```bash
cd /var/www
git clone https://github.com/seu-usuario/face-recognition-service.git
cd face-recognition-service
```

Siga as instruções em `DEPLOY.md` para configurar o serviço.
