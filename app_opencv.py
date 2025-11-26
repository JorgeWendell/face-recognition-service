"""
Serviço de Reconhecimento Facial usando OpenCV
Versão alternativa que não requer dlib ou face_recognition
"""

import os
import base64
import io
from typing import Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
import cv2
import numpy as np
from PIL import Image
import requests
from requests.auth import HTTPBasicAuth

# Carregar variáveis de ambiente
load_dotenv()

app = FastAPI(title="Face Recognition Service (OpenCV)", version="1.0.0")

# Configurar CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Em produção, especificar origens permitidas
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configurações
NEXTCLOUD_WEBDAV_URL = os.getenv("NEXTCLOUD_WEBDAV_URL", "http://192.168.15.10/remote.php/dav/files/Ponto")
NEXTCLOUD_USER = os.getenv("NEXTCLOUD_USER", "")
NEXTCLOUD_PASSWORD = os.getenv("NEXTCLOUD_PASSWORD", "")
FACE_MATCH_THRESHOLD = float(os.getenv("FACE_MATCH_THRESHOLD", "0.6"))

# Carregar detector de faces do OpenCV (Haar Cascade)
# Não requer opencv-contrib, funciona com opencv-python básico
face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')


class RecognizeWithCollaboratorsRequest(BaseModel):
    image_base64: str
    latitude: Optional[str] = None
    longitude: Optional[str] = None
    dispositivo_info: Optional[str] = None
    colaboradores: list[dict]


class RecognizeResponse(BaseModel):
    success: bool
    colaborador_id: Optional[str] = None
    colaborador_nome: Optional[str] = None
    score: Optional[float] = None
    error: Optional[str] = None


class UploadFacialRequest(BaseModel):
    colaborador_id: str
    image_base64: str


class UploadFacialResponse(BaseModel):
    success: bool
    url: Optional[str] = None
    error: Optional[str] = None


def extract_nextcloud_path(url: str) -> Optional[str]:
    """Extrai o path do Nextcloud de uma URL"""
    if not url:
        return None
    
    # Se for URL da API proxy, extrair o path
    if "/api/nextcloud/image?path=" in url:
        import urllib.parse
        parsed = urllib.parse.urlparse(url)
        params = urllib.parse.parse_qs(parsed.query)
        return params.get("path", [None])[0]
    
    # Se for URL WebDAV direta, extrair o path após colaboradores/
    if "/colaboradores/" in url:
        parts = url.split("/colaboradores/")
        if len(parts) > 1:
            return f"colaboradores/{parts[1].split('?')[0]}"
    
    # Se for URL WebDAV completa
    if "/remote.php/dav/files/" in url:
        parts = url.split("/remote.php/dav/files/")
        if len(parts) > 1:
            return parts[1]
    
    return None


def download_image_from_nextcloud(file_path: str) -> Optional[bytes]:
    """Baixa uma imagem do Nextcloud"""
    try:
        url = f"{NEXTCLOUD_WEBDAV_URL}/{file_path}"
        response = requests.get(
            url,
            auth=HTTPBasicAuth(NEXTCLOUD_USER, NEXTCLOUD_PASSWORD),
            timeout=10
        )
        
        if response.status_code == 200:
            return response.content
        else:
            print(f"Erro ao baixar imagem do Nextcloud: {response.status_code}")
            return None
    except Exception as e:
        print(f"Exceção ao baixar imagem do Nextcloud: {e}")
        return None


def base64_to_image(base64_string: str) -> Optional[np.ndarray]:
    """Converte base64 para array numpy (OpenCV)"""
    try:
        # Remover prefixo data:image se existir
        if "," in base64_string:
            base64_string = base64_string.split(",")[1]
        
        # Decodificar base64
        image_data = base64.b64decode(base64_string)
        
        # Converter para numpy array
        nparr = np.frombuffer(image_data, np.uint8)
        
        # Decodificar imagem
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if img is None:
            return None
        
        # Converter para escala de cinza
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        return gray
    except Exception as e:
        print(f"Erro ao converter base64 para imagem: {e}")
        return None


def detect_and_extract_face(image: np.ndarray) -> Optional[np.ndarray]:
    """Detecta e extrai a face da imagem"""
    try:
        # Detectar faces
        faces = face_cascade.detectMultiScale(
            image,
            scaleFactor=1.1,
            minNeighbors=5,
            minSize=(30, 30)
        )
        
        if len(faces) == 0:
            return None
        
        # Pegar a primeira face detectada
        (x, y, w, h) = faces[0]
        
        # Extrair região da face
        face_roi = image[y:y+h, x:x+w]
        
        # Redimensionar para tamanho padrão (melhora comparação)
        face_roi = cv2.resize(face_roi, (200, 200))
        
        return face_roi
    except Exception as e:
        print(f"Erro ao detectar face: {e}")
        return None




def compare_faces_opencv(captured_face: np.ndarray, stored_face: np.ndarray) -> tuple[bool, float]:
    """
    Compara duas faces usando histograma e correlação
    Retorna (match, similarity_score)
    """
    try:
        # Método 1: Comparação de histogramas
        hist1 = cv2.calcHist([captured_face], [0], None, [256], [0, 256])
        hist2 = cv2.calcHist([stored_face], [0], None, [256], [0, 256])
        
        # Correlação de histogramas
        correlation = cv2.compareHist(hist1, hist2, cv2.HISTCMP_CORREL)
        
        # Método 2: Template matching
        if captured_face.shape == stored_face.shape:
            result = cv2.matchTemplate(captured_face, stored_face, cv2.TM_CCOEFF_NORMED)
            template_match = np.max(result)
        else:
            template_match = 0.0
        
        # Combinar scores (média ponderada)
        similarity = (correlation * 0.6 + template_match * 0.4)
        
        # Normalizar para 0-1
        similarity = max(0.0, min(1.0, similarity))
        
        match = similarity >= FACE_MATCH_THRESHOLD
        
        return match, similarity
    except Exception as e:
        print(f"Erro ao comparar faces: {e}")
        return False, 0.0


@app.get("/")
async def root():
    """Endpoint de health check"""
    return {"status": "ok", "service": "face-recognition-opencv"}


@app.post("/recognize-with-collaborators", response_model=RecognizeResponse)
async def recognize_face_with_collaborators(
    request: RecognizeWithCollaboratorsRequest
):
    """
    Reconhece uma face comparando com lista de colaboradores fornecida
    Usa OpenCV sem dependência de dlib
    """
    try:
        # Converter base64 para imagem
        captured_image = base64_to_image(request.image_base64)
        if captured_image is None:
            return RecognizeResponse(
                success=False,
                error="Não foi possível processar a imagem. Verifique o formato."
            )
        
        # Detectar e extrair face da imagem capturada
        captured_face = detect_and_extract_face(captured_image)
        if captured_face is None:
            return RecognizeResponse(
                success=False,
                error="Nenhuma face detectada na imagem. Posicione-se melhor em frente à câmera."
            )
        
        # Comparar com cada colaborador
        best_match = None
        best_score = 0.0
        
        for colaborador in request.colaboradores:
            foto_url = colaborador.get("foto_url")
            if not foto_url:
                continue
            
            # Extrair path do Nextcloud
            file_path = extract_nextcloud_path(foto_url)
            if not file_path:
                print(f"Não foi possível extrair path da URL: {foto_url}")
                continue
            
            # Baixar facial do Nextcloud
            facial_image_bytes = download_image_from_nextcloud(file_path)
            if not facial_image_bytes:
                print(f"Não foi possível baixar facial do colaborador {colaborador.get('id')}")
                continue
            
            # Converter bytes para array numpy
            try:
                nparr = np.frombuffer(facial_image_bytes, np.uint8)
                facial_image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                if facial_image is None:
                    continue
                facial_gray = cv2.cvtColor(facial_image, cv2.COLOR_BGR2GRAY)
            except Exception as e:
                print(f"Erro ao processar imagem do colaborador {colaborador.get('id')}: {e}")
                continue
            
            # Detectar e extrair face da facial cadastrada
            stored_face = detect_and_extract_face(facial_gray)
            if stored_face is None:
                print(f"Não foi possível detectar face na facial do colaborador {colaborador.get('id')}")
                continue
            
            # Comparar faces
            match, score = compare_faces_opencv(captured_face, stored_face)
            
            print(f"Colaborador {colaborador.get('id')}: match={match}, score={score:.3f}")
            
            if match and score > best_score:
                best_match = colaborador
                best_score = score
        
        if best_match:
            return RecognizeResponse(
                success=True,
                colaborador_id=best_match.get("id"),
                colaborador_nome=best_match.get("nome_completo"),
                score=best_score
            )
        else:
            return RecognizeResponse(
                success=False,
                error="Colaborador não reconhecido. Verifique se a facial está cadastrada corretamente."
            )
        
    except Exception as e:
        print(f"Erro no reconhecimento: {e}")
        import traceback
        traceback.print_exc()
        return RecognizeResponse(
            success=False,
            error=f"Erro ao processar reconhecimento: {str(e)}"
        )


def upload_image_to_nextcloud(file_path: str, image_bytes: bytes) -> Optional[str]:
    """Faz upload de uma imagem para o Nextcloud"""
    try:
        url = f"{NEXTCLOUD_WEBDAV_URL}/{file_path}"
        
        # Criar diretório se não existir
        dir_path = "/".join(file_path.split("/")[:-1])
        if dir_path:
            dir_url = f"{NEXTCLOUD_WEBDAV_URL}/{dir_path}"
            try:
                requests.request("MKCOL", dir_url, auth=HTTPBasicAuth(NEXTCLOUD_USER, NEXTCLOUD_PASSWORD))
            except:
                pass  # Diretório pode já existir
        
        # Fazer upload do arquivo
        response = requests.put(
            url,
            data=image_bytes,
            auth=HTTPBasicAuth(NEXTCLOUD_USER, NEXTCLOUD_PASSWORD),
            headers={"Content-Type": "image/jpeg"},
            timeout=30
        )
        
        if response.status_code in [200, 201, 204]:
            # Retornar path relativo que será usado pela API proxy do Next.js
            return file_path
        else:
            print(f"Erro ao fazer upload: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"Exceção ao fazer upload: {e}")
        return None


@app.post("/upload-facial", response_model=UploadFacialResponse)
async def upload_facial(request: UploadFacialRequest):
    """
    Faz upload de uma facial para o Nextcloud
    
    Valida que a imagem contém uma face detectável antes de fazer upload
    """
    try:
        # Converter base64 para imagem
        image_array = base64_to_image(request.image_base64)
        if image_array is None:
            return UploadFacialResponse(
                success=False,
                error="Não foi possível processar a imagem. Verifique o formato."
            )
        
        # Validar que há uma face detectável
        detected_face = detect_and_extract_face(image_array)
        if detected_face is None:
            return UploadFacialResponse(
                success=False,
                error="Nenhuma face detectada na imagem. Por favor, tire uma foto onde sua face esteja claramente visível."
            )
        
        # Converter imagem de volta para bytes (JPEG)
        # Usar a imagem original (colorida) para upload
        try:
            # Decodificar base64 novamente para pegar imagem original
            if "," in request.image_base64:
                base64_string = request.image_base64.split(",")[1]
            else:
                base64_string = request.image_base64
            
            image_data = base64.b64decode(base64_string)
            
            # Opcional: redimensionar/otimizar imagem aqui se necessário
            
        except Exception as e:
            print(f"Erro ao processar imagem para upload: {e}")
            return UploadFacialResponse(
                success=False,
                error="Erro ao processar imagem para upload."
            )
        
        # Gerar nome do arquivo
        import time
        timestamp = int(time.time() * 1000)
        filename = f"facial_{timestamp}.jpg"
        file_path = f"colaboradores/{request.colaborador_id}/{filename}"
        
        # Fazer upload para Nextcloud
        uploaded_path = upload_image_to_nextcloud(file_path, image_data)
        
        if not uploaded_path:
            return UploadFacialResponse(
                success=False,
                error="Erro ao fazer upload para o Nextcloud. Verifique as credenciais."
            )
        
        # Retornar path que será salvo no banco
        # O Next.js vai converter isso para URL da API proxy
        return UploadFacialResponse(
            success=True,
            url=uploaded_path
        )
        
    except Exception as e:
        print(f"Erro no upload de facial: {e}")
        import traceback
        traceback.print_exc()
        return UploadFacialResponse(
            success=False,
            error=f"Erro ao processar upload: {str(e)}"
        )


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("API_PORT", "8000"))
    host = os.getenv("API_HOST", "0.0.0.0")
    uvicorn.run(app, host=host, port=port)

