"""
Serviço de Reconhecimento Facial
API FastAPI para reconhecimento facial usando face_recognition
"""

import os
import base64
import io
from typing import Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
import face_recognition
import numpy as np
from PIL import Image
import requests
from requests.auth import HTTPBasicAuth

# Carregar variáveis de ambiente
load_dotenv()

app = FastAPI(title="Face Recognition Service", version="1.0.0")

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


class RecognizeRequest(BaseModel):
    image_base64: str
    latitude: Optional[str] = None
    longitude: Optional[str] = None
    dispositivo_info: Optional[str] = None


class RecognizeResponse(BaseModel):
    success: bool
    colaborador_id: Optional[str] = None
    colaborador_nome: Optional[str] = None
    score: Optional[float] = None
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
    """Converte base64 para array numpy (formato face_recognition)"""
    try:
        # Remover prefixo data:image se existir
        if "," in base64_string:
            base64_string = base64_string.split(",")[1]
        
        # Decodificar base64
        image_data = base64.b64decode(base64_string)
        
        # Converter para PIL Image
        image = Image.open(io.BytesIO(image_data))
        
        # Converter para RGB se necessário
        if image.mode != "RGB":
            image = image.convert("RGB")
        
        # Converter para array numpy
        image_array = np.array(image)
        
        return image_array
    except Exception as e:
        print(f"Erro ao converter base64 para imagem: {e}")
        return None


def extract_face_encoding(image_array: np.ndarray) -> Optional[np.ndarray]:
    """Extrai encoding facial de uma imagem"""
    try:
        # face_recognition espera RGB
        encodings = face_recognition.face_encodings(image_array)
        
        if len(encodings) == 0:
            return None
        
        # Retornar o primeiro encoding (primeira face detectada)
        return encodings[0]
    except Exception as e:
        print(f"Erro ao extrair encoding facial: {e}")
        return None


def compare_faces(encoding1: np.ndarray, encoding2: np.ndarray, threshold: float = 0.6) -> tuple[bool, float]:
    """Compara dois encodings faciais e retorna (match, distance)"""
    try:
        # Calcular distância euclidiana
        distance = face_recognition.face_distance([encoding1], encoding2)[0]
        
        # Converter distância para similaridade (0-1)
        similarity = 1 - distance
        
        # Verificar se está acima do threshold
        match = similarity >= threshold
        
        return match, similarity
    except Exception as e:
        print(f"Erro ao comparar faces: {e}")
        return False, 0.0


@app.get("/")
async def root():
    """Endpoint de health check"""
    return {"status": "ok", "service": "face-recognition"}


@app.post("/recognize", response_model=RecognizeResponse)
async def recognize_face(request: RecognizeRequest):
    """
    Reconhece uma face na imagem fornecida
    
    Compara a imagem capturada com as faciais cadastradas no Nextcloud
    """
    try:
        # Converter base64 para imagem
        image_array = base64_to_image(request.image_base64)
        if image_array is None:
            return RecognizeResponse(
                success=False,
                error="Não foi possível processar a imagem. Verifique o formato."
            )
        
        # Extrair encoding da face capturada
        captured_encoding = extract_face_encoding(image_array)
        if captured_encoding is None:
            return RecognizeResponse(
                success=False,
                error="Nenhuma face detectada na imagem. Posicione-se melhor em frente à câmera."
            )
        
        # Buscar colaboradores com facial cadastrada
        # Nota: Em produção, isso deveria vir de uma API do Next.js ou banco de dados
        # Por enquanto, vamos precisar que o Next.js envie a lista de colaboradores
        # ou criar um endpoint separado para buscar colaboradores
        
        # Por enquanto, retornar erro informando que precisa integrar com banco
        return RecognizeResponse(
            success=False,
            error="Serviço em desenvolvimento. Aguardando integração com banco de dados."
        )
        
    except Exception as e:
        print(f"Erro no reconhecimento: {e}")
        return RecognizeResponse(
            success=False,
            error=f"Erro ao processar reconhecimento: {str(e)}"
        )


class RecognizeWithCollaboratorsRequest(BaseModel):
    image_base64: str
    latitude: Optional[str] = None
    longitude: Optional[str] = None
    dispositivo_info: Optional[str] = None
    colaboradores: list[dict]


@app.post("/recognize-with-collaborators", response_model=RecognizeResponse)
async def recognize_face_with_collaborators(
    request: RecognizeWithCollaboratorsRequest
):
    """
    Reconhece uma face comparando com lista de colaboradores fornecida
    
    Request body:
    {
        "image_base64": "...",
        "latitude": "...",
        "longitude": "...",
        "dispositivo_info": "...",
        "colaboradores": [
            {
                "id": "...",
                "nome_completo": "...",
                "foto_url": "..."
            },
            ...
        ]
    }
    """
    try:
        # Converter base64 para imagem
        image_array = base64_to_image(request.image_base64)
        if image_array is None:
            return RecognizeResponse(
                success=False,
                error="Não foi possível processar a imagem. Verifique o formato."
            )
        
        # Extrair encoding da face capturada
        captured_encoding = extract_face_encoding(image_array)
        if captured_encoding is None:
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
                facial_image = Image.open(io.BytesIO(facial_image_bytes))
                if facial_image.mode != "RGB":
                    facial_image = facial_image.convert("RGB")
                facial_array = np.array(facial_image)
            except Exception as e:
                print(f"Erro ao processar imagem do colaborador {colaborador.get('id')}: {e}")
                continue
            
            # Extrair encoding da facial cadastrada
            stored_encoding = extract_face_encoding(facial_array)
            if stored_encoding is None:
                print(f"Não foi possível extrair encoding da facial do colaborador {colaborador.get('id')}")
                continue
            
            # Comparar encodings
            match, score = compare_faces(captured_encoding, stored_encoding, FACE_MATCH_THRESHOLD)
            
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


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("API_PORT", "9090"))
    host = os.getenv("API_HOST", "0.0.0.0")
    uvicorn.run(app, host=host, port=port)

