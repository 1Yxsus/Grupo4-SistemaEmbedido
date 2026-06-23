import os
import json
import io
import hashlib
import hmac
import base64
from datetime import datetime, timezone, timedelta
import numpy as np
import cv2
import torch
import torch.nn as nn
import torch.nn.functional as F
from PIL import Image
from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import credentials, db
import requests
import torchvision.models as models
from torchvision import transforms
from ultralytics import YOLO

app = Flask(__name__)

@app.route('/')
def health_check():
    return jsonify({
        "status": "ok",
        "message": "API activa"
    }), 200

# ==========================================
# 1. CONFIGURACIÓN E INICIALIZACIÓN DE IA (YOLO + EFFICIENTNET)
# ==========================================

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Dispositivo para inferencia: {device}")

# Mapeo de Categorías de Maduración (15 clases)
MAPEO_MADUREZ = {
    0: 'Plátano Inmaduro (Verde) 🍌🟢',
    1: 'Plátano Fresco-Maduro 🍌🟡🟢',
    2: 'Plátano Maduro 🍌🟡',
    3: 'Plátano Muy Maduro 🍌🟤🟡',
    4: 'Plátano Podrido 🍌🟤',
    5: 'Manzana Inmadura 🍎🟢',
    6: 'Manzana Fresco-Madura 🍎🟡🟢',
    7: 'Manzana Madura 🍎🔴',
    8: 'Manzana Muy Madura 🍎🟤🔴',
    9: 'Manzana Podrida 🍎🟤',
    10: 'Naranja Inmadura 🍊🟢',
    11: 'Naranja Fresco-Madura 🍊🟡🟢',
    12: 'Naranja Madura 🍊🧡',
    13: 'Naranja Muy Madura 🍊🟤🧡',
    14: 'Naranja Podrida 🍊🟤'
}

# Definición de rangos de clases por tipo de fruta
RANGOS_FRUTAS = {
    'platano': (0, 5),    # Clases 0 a 4
    'manzana': (5, 10),   # Clases 5 a 9
    'naranja': (10, 15)   # Clases 10 a 14
}

def cargar_modelo_ripeness(ruta_pesos, device_obj):
    print(f"[INFO] Inicializando arquitectura EfficientNet-B5 para maduración...")
    modelo = models.efficientnet_b5(weights=None)
    num_caracteristicas = modelo.classifier[1].in_features
    modelo.classifier[1] = nn.Linear(num_caracteristicas, 15)
    
    print(f"[INFO] Cargando pesos del experto de maduración desde: {ruta_pesos}")
    modelo.load_state_dict(torch.load(ruta_pesos, map_location=device_obj))
    modelo = modelo.to(device_obj)
    modelo.eval()
    return modelo

import urllib.request

def asegurar_modelo(url, destino):
    """
    Verifica si el modelo existe en el destino local.
    Si no existe, lo descarga desde la URL especificada en bloques de 1MB para no saturar la RAM.
    """
    if not os.path.exists(destino):
        print(f"[IA] El modelo no existe en {destino}. Descargando desde {url}...")
        os.makedirs(os.path.dirname(destino), exist_ok=True)
        try:
            req = urllib.request.Request(
                url, 
                headers={'User-Agent': 'Mozilla/5.0'}
            )
            with urllib.request.urlopen(req) as response_download:
                with open(destino, 'wb') as out_file:
                    while True:
                        chunk = response_download.read(1024 * 1024) # 1MB chunk
                        if not chunk:
                            break
                        out_file.write(chunk)
            print(f"[IA] Descarga finalizada y guardada en {destino}")
        except Exception as err:
            print(f"[IA] Error al descargar el modelo desde {url}: {err}")
            if os.path.exists(destino):
                os.remove(destino)
    else:
        print(f"[IA] El modelo ya existe en {destino}.")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
YOLO_PATH = os.path.join(BASE_DIR, "YOLO", "best.pt")
RIPENESS_PATH = os.path.join(BASE_DIR, "EficientNet", "ripeness.pth")

# URL por defecto (GitHub Releases)
URL_YOLO = os.environ.get(
    "URL_YOLO",
    "https://github.com/1Yxsus/DeteccionDeFrutas/releases/download/v1.0.0/best.pt"
)
URL_RIPENESS = os.environ.get(
    "URL_RIPENESS",
    "https://github.com/1Yxsus/DeteccionDeFrutas/releases/download/v1.0.0/ripeness.pth"
)

# Asegurar que ambos modelos estén descargados antes de inicializarlos
asegurar_modelo(URL_YOLO, YOLO_PATH)
asegurar_modelo(URL_RIPENESS, RIPENESS_PATH)

print("Cargando modelo YOLOv11...")
try:
    modelo_yolo = YOLO(YOLO_PATH)
    print("¡Modelo YOLOv11 cargado exitosamente!")
except Exception as e:
    print(f"Error crítico al cargar YOLO: {e}")
    modelo_yolo = None

print("Cargando modelo de maduración EfficientNet...")
try:
    modelo_ripeness = cargar_modelo_ripeness(RIPENESS_PATH, device)
    print("¡Modelo EfficientNet cargado exitosamente!")
except Exception as e:
    print(f"Error crítico al cargar EfficientNet: {e}")
    modelo_ripeness = None

def preprocesar_recorte(recorte_bgr):
    """
    Preprocesa la imagen recortada de la fruta para alimentar a EfficientNet-B5.
    """
    recorte_rgb = cv2.cvtColor(recorte_bgr, cv2.COLOR_BGR2RGB)
    imagen_pil = Image.fromarray(recorte_rgb)
    
    transformacion = transforms.Compose([
        transforms.Resize((456, 456)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])
    
    tensor_imagen = transformacion(imagen_pil).unsqueeze(0)
    return tensor_imagen

def procesar_inferencia_cascada(img_bgr, conf_yolo=0.25, conf_ripeness=0.15):
    """
    Ejecuta el pipeline de detección YOLO y clasificación de madurez con EfficientNet.
    Retorna la imagen anotada y la lista de detecciones detalladas.
    """
    if modelo_yolo is None or modelo_ripeness is None:
        raise RuntimeError("Modelos de IA no cargados en el servidor")
        
    img_h, img_w, _ = img_bgr.shape
    annotated_img = img_bgr.copy()
    
    resultados_yolo = modelo_yolo.predict(source=img_bgr, conf=conf_yolo, device=device)
    resultado = resultados_yolo[0]
    
    cajas = resultado.boxes
    mascaras = resultado.masks
    nombres_clases_yolo = resultado.names
    
    detecciones_procesadas = []
    
    if cajas is None or len(cajas) == 0:
        return annotated_img, detecciones_procesadas
        
    mascaras_resized = None
    if mascaras is not None:
        tensor_mascaras = mascaras.data.float()
        tensor_mascaras_resized = F.interpolate(
            tensor_mascaras.unsqueeze(1),
            size=(img_h, img_w),
            mode='bilinear',
            align_corners=False
        ).squeeze(1)
        mascaras_resized = (tensor_mascaras_resized > 0.5).cpu().numpy().astype(np.uint8)
        
    colores_frutas = {
        'platano': (0, 242, 255),  # Amarillo
        'naranja': (0, 128, 255),  # Naranja
        'manzana': (0, 0, 255),    # Rojo
        'palta': (0, 255, 0)       # Verde
    }
    
    for i, box in enumerate(cajas):
        cls_id = int(box.cls[0].item())
        cls_name = nombres_clases_yolo[cls_id]
        conf = float(box.conf[0].item())
        
        x1, y1, x2, y2 = map(int, box.xyxy[0].cpu().numpy())
        x1, y1 = max(0, x1), max(0, y1)
        x2, y2 = min(img_w, x2), min(img_h, y2)
        
        fruta_key = cls_name.lower()
        if fruta_key not in RANGOS_FRUTAS:
            continue
            
        color = colores_frutas.get(fruta_key, (255, 255, 255))
        mask = mascaras_resized[i] if mascaras_resized is not None else None
        
        masked_img = np.zeros_like(img_bgr)
        if mask is not None:
            masked_img[mask > 0] = img_bgr[mask > 0]
        else:
            masked_img[y1:y2, x1:x2] = img_bgr[y1:y2, x1:x2]
            
        crop_img = masked_img[y1:y2, x1:x2]
        if crop_img.size == 0 or crop_img.shape[0] == 0 or crop_img.shape[1] == 0:
            continue
            
        tensor_crop = preprocesar_recorte(crop_img).to(device)
        
        with torch.no_grad():
            outputs = modelo_ripeness(tensor_crop)
            idx_inicio, idx_fin = RANGOS_FRUTAS[fruta_key]
            
            logits_filtrados = outputs[0].clone()
            for idx in range(15):
                if idx < idx_inicio or idx >= idx_fin:
                    logits_filtrados[idx] = -float('inf')
                    
            pred_idx = torch.argmax(logits_filtrados).item()
            probabilidades = torch.softmax(outputs[0], dim=0)
            conf_madurez = probabilidades[pred_idx].item()
            
        estado_madurez = MAPEO_MADUREZ.get(pred_idx, "Desconocido")
        
        if conf_madurez < conf_ripeness:
            continue
            
        if mask is not None:
            idx_mask = (mask > 0)
            annotated_img[idx_mask] = (annotated_img[idx_mask] * 0.6 + np.array(color, dtype=np.float32) * 0.4).astype(np.uint8)
            
        idx_tabla = len(detecciones_procesadas) + 1
        cv2.rectangle(annotated_img, (x1, y1), (x2, y2), color, 2)
        label_texto = f"#{idx_tabla} {cls_name.upper()} {conf:.0%}"
        cv2.putText(annotated_img, label_texto, (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)
        
        detecciones_procesadas.append({
            'index': idx_tabla,
            'clase': cls_name,
            'caja': (x1, y1, x2, y2),
            'madurez': estado_madurez,
            'confianza_madurez': conf_madurez
        })
        
    return annotated_img, detecciones_procesadas


def upload_image_to_cloudinary(image_bytes, public_id):
    """Sube una imagen a Cloudinary usando su API HTTP directa."""

    cloud_name = os.environ.get("CLOUDINARY_CLOUD_NAME")
    api_key = os.environ.get("CLOUDINARY_API_KEY")
    api_secret = os.environ.get("CLOUDINARY_API_SECRET")

    if not cloud_name or not api_key or not api_secret:
        raise RuntimeError("Faltan credenciales de Cloudinary en variables de entorno")

    folder = os.environ.get("CLOUDINARY_FOLDER", "esp32cam")
    timestamp = str(int(datetime.utcnow().timestamp()))

    params = {
        "folder": folder,
        "public_id": public_id,
        "timestamp": timestamp,
    }

    signature_payload = "&".join(f"{key}={value}" for key, value in sorted(params.items()))
    signature = hashlib.sha1(f"{signature_payload}{api_secret}".encode("utf-8")).hexdigest()

    files = {"file": (f"{public_id}.jpg", io.BytesIO(image_bytes), "image/jpeg")}
    data = {
        "api_key": api_key,
        "timestamp": timestamp,
        "signature": signature,
        "folder": folder,
        "public_id": public_id,
    }

    response = requests.post(
        f"https://api.cloudinary.com/v1_1/{cloud_name}/image/upload",
        data=data,
        files=files,
        timeout=30,
    )
    response.raise_for_status()
    return response.json()


def delete_image_from_cloudinary(public_id):
    """Elimina una imagen de Cloudinary usando su API HTTP de destrucción."""
    cloud_name = os.environ.get("CLOUDINARY_CLOUD_NAME")
    api_key = os.environ.get("CLOUDINARY_API_KEY")
    api_secret = os.environ.get("CLOUDINARY_API_SECRET")

    if not cloud_name or not api_key or not api_secret:
        raise RuntimeError("Faltan credenciales de Cloudinary en variables de entorno")

    timestamp = str(int(datetime.utcnow().timestamp()))

    params = {
        "public_id": public_id,
        "timestamp": timestamp,
    }

    signature_payload = "&".join(f"{key}={value}" for key, value in sorted(params.items()))
    signature = hashlib.sha1(f"{signature_payload}{api_secret}".encode("utf-8")).hexdigest()

    data = {
        "api_key": api_key,
        "timestamp": timestamp,
        "public_id": public_id,
        "signature": signature,
    }

    response = requests.post(
        f"https://api.cloudinary.com/v1_1/{cloud_name}/image/destroy",
        data=data,
        timeout=30,
    )
    response.raise_for_status()
    return response.json()


import threading
import time

def programar_borrado_temporal(public_id, delay_seconds=600):
    """Lanza un hilo en segundo plano para borrar la foto tras N segundos."""
    def borrado_worker():
        print(f"[TEMPORAL] Esperando {delay_seconds} segundos para eliminar {public_id}...")
        time.sleep(delay_seconds)
        try:
            res = delete_image_from_cloudinary(public_id)
            print(f"[TEMPORAL] Imagen {public_id} eliminada de Cloudinary: {res}")
        except Exception as e:
            print(f"[TEMPORAL] Error al eliminar imagen {public_id}: {e}")

    thread = threading.Thread(target=borrado_worker)
    thread.daemon = True
    thread.start()


# ==========================================
# 2. CONFIGURACIÓN DE FIREBASE
# ==========================================
try:
    firebase_credentials_json = os.environ.get("FIREBASE_CREDENTIALS_JSON")
    firebase_credentials_path = os.environ.get("FIREBASE_CREDENTIALS_PATH", "firebase-key.json")

    if firebase_credentials_json:
        cred = credentials.Certificate(json.loads(firebase_credentials_json))
    else:
        cred = credentials.Certificate(firebase_credentials_path)

    firebase_admin.initialize_app(cred, {
        'databaseURL': os.environ.get(
            'FIREBASE_DATABASE_URL',
            'https://sistemasdigitales-5c91f-default-rtdb.firebaseio.com/'
        )
    })
    print("Conexión con Firebase establecida correctamente.")
except Exception as e:
    print(f"Error al conectar con Firebase: {e}")


# ==========================================
# 3. ENDPOINTS EXCLUSIVOS PARA INFERENCIA DE IMÁGENES
# ==========================================

@app.route('/api/data', methods=['POST'])
def recibir_datos_iot():
    try:
        if modelo_yolo is None or modelo_ripeness is None:
            return jsonify({"status": "error", "message": "Los modelos de IA no están disponibles en el servidor"}), 500

        # A. Captura de la imagen enviada por el ESP32-CAM u otro cliente
        img_bytes = request.data
        if not img_bytes and request.files:
            if 'image' in request.files:
                img_bytes = request.files['image'].read()
            else:
                first_file_key = list(request.files.keys())[0]
                img_bytes = request.files[first_file_key].read()

        if not img_bytes:
            return jsonify({"status": "error", "message": "Imagen vacía o ausente en la petición"}), 400

        # Convertir bytes a imagen PIL y luego a formato BGR de OpenCV
        img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
        img_bgr = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)

        # Parámetros opcionales de umbral
        conf_yolo = request.args.get('conf_yolo', default=0.25, type=float)
        conf_ripeness = request.args.get('conf_ripeness', default=0.15, type=float)

        # B. Ejecución de la inferencia en cascada
        annotated_img, detecciones = procesar_inferencia_cascada(
            img_bgr, 
            conf_yolo=conf_yolo, 
            conf_ripeness=conf_ripeness
        )

        # Determinar estado de maduración y confianza general
        if len(detecciones) == 0:
            resultado_ia_general = "No se detectó ninguna fruta"
            porcentaje_confianza_general = 0.0
        else:
            # Seleccionar la detección con mayor confianza de madurez
            best_det = max(detecciones, key=lambda x: x['confianza_madurez'])
            resultado_ia_general = best_det['madurez']
            porcentaje_confianza_general = float(best_det['confianza_madurez'] * 100)

        # Obtener la hora actual en la zona horaria de Perú (UTC-5)
        tz_peru = timezone(timedelta(hours=-5))
        timestamp_actual = datetime.now(tz_peru).strftime("%d/%m/%y %H:%M")
        public_id = f"esp32cam/{timestamp_actual.replace('/', '-').replace(' ', '_').replace(':', '-') }"

        # Convertir la imagen anotada (BGR) a bytes JPEG
        _, buffer = cv2.imencode('.jpg', annotated_img)
        annotated_bytes = buffer.tobytes()

        # Guardar la imagen localmente en la carpeta static para desarrollo y visualización local
        static_dir = os.path.join(BASE_DIR, "static")
        os.makedirs(static_dir, exist_ok=True)
        cv2.imwrite(os.path.join(static_dir, "data_result.jpg"), annotated_img)
        imagen_url_local = f"{request.host_url}static/data_result.jpg"

        # C. Subida de la imagen anotada a Cloudinary
        imagen_url = None
        imagen_public_id = None
        try:
            cloudinary_result = upload_image_to_cloudinary(annotated_bytes, public_id)
            imagen_url = cloudinary_result.get("secure_url")
            imagen_public_id = cloudinary_result.get("public_id")
        except Exception as cloudinary_error:
            print(f"Error al subir imagen a Cloudinary: {cloudinary_error}")

        # D. Registro del veredicto general en Firebase
        try:
            historial_data = {
                'fecha_hora': timestamp_actual,
                'lote': 'Lote_Campoy_Alpha',
                'estado_maduracion': resultado_ia_general,
                'confianza': f"{porcentaje_confianza_general:.2f}%",
                'imagen_url': imagen_url,
                'imagen_public_id': imagen_public_id,
            }
            db.reference('/historial_ia').push(historial_data)
        except Exception as db_error:
            print(f"Error al registrar en Firebase: {db_error}")

        # Responder al cliente
        return jsonify({
            "status": "success",
            "message": "Imagen procesada y clasificada en Firebase exitosamente",
            "ia_ejecutada": True,
            "prediccion": resultado_ia_general,
            "confianza": f"{porcentaje_confianza_general:.2f}%",
            "confianza_valor": porcentaje_confianza_general,
            "imagen_url": imagen_url,
            "imagen_url_local": imagen_url_local,
            "imagen_public_id": imagen_public_id,
            "detecciones": detecciones
        }), 200

    except Exception as e:
        return jsonify({"status": "error", "message": f"Fallo en la API interna: {str(e)}"}), 500


@app.route('/api/test', methods=['POST'])
def test_datos_iot():
    try:
        if modelo_yolo is None or modelo_ripeness is None:
            return jsonify({"status": "error", "message": "Los modelos de IA no están disponibles en el servidor"}), 500

        # A. Captura de la imagen enviada
        img_bytes = request.data
        if not img_bytes and request.files:
            if 'image' in request.files:
                img_bytes = request.files['image'].read()
            else:
                first_file_key = list(request.files.keys())[0]
                img_bytes = request.files[first_file_key].read()

        if not img_bytes:
            return jsonify({"status": "error", "message": "Imagen vacía o ausente en la petición"}), 400

        # Convertir bytes a BGR de OpenCV
        img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
        img_bgr = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)

        # Parámetros opcionales de umbral
        conf_yolo = request.args.get('conf_yolo', default=0.25, type=float)
        conf_ripeness = request.args.get('conf_ripeness', default=0.15, type=float)

        # B. Ejecución de la inferencia en cascada
        annotated_img, detecciones = procesar_inferencia_cascada(
            img_bgr, 
            conf_yolo=conf_yolo, 
            conf_ripeness=conf_ripeness
        )

        # Determinar estado de maduración y confianza general
        if len(detecciones) == 0:
            resultado_ia_general = "No se detectó ninguna fruta"
            porcentaje_confianza_general = 0.0
        else:
            best_det = max(detecciones, key=lambda x: x['confianza_madurez'])
            resultado_ia_general = best_det['madurez']
            porcentaje_confianza_general = float(best_det['confianza_madurez'] * 100)

        # Convertir la imagen anotada (BGR) a bytes JPEG
        _, buffer = cv2.imencode('.jpg', annotated_img)
        annotated_bytes = buffer.tobytes()

        # Guardar la imagen localmente en la carpeta static para desarrollo y visualización local
        static_dir = os.path.join(BASE_DIR, "static")
        os.makedirs(static_dir, exist_ok=True)
        cv2.imwrite(os.path.join(static_dir, "test_result.jpg"), annotated_img)
        imagen_url_local = f"{request.host_url}static/test_result.jpg"

        # Convertir la imagen a Base64 para visualización instantánea temporal
        imagen_base64 = base64.b64encode(annotated_bytes).decode('utf-8')

        # C. Intentar subir a Cloudinary de manera opcional para tener URL temporal
        imagen_url = None
        imagen_public_id = None
        tz_peru = timezone(timedelta(hours=-5))
        timestamp_actual = datetime.now(tz_peru).strftime("%d/%m/%y %H:%M")
        public_id = f"esp32cam/test/{timestamp_actual.replace('/', '-').replace(' ', '_').replace(':', '-') }"
        try:
            cloudinary_result = upload_image_to_cloudinary(annotated_bytes, public_id)
            imagen_url = cloudinary_result.get("secure_url")
            imagen_public_id = cloudinary_result.get("public_id")
        except Exception as cloudinary_error:
            print(f"Error al subir imagen de test a Cloudinary: {cloudinary_error}")

        # D. Programar el borrado automático de la imagen de Cloudinary tras 10 minutos (600 segundos)
        if imagen_public_id:
            try:
                programar_borrado_temporal(imagen_public_id, delay_seconds=600)
            except Exception as schedule_err:
                print(f"Error al programar el borrado temporal: {schedule_err}")

        # Responder al cliente (SIN enviar a Firebase)
        return jsonify({
            "status": "success",
            "message": "Imagen procesada en modo test exitosamente",
            "ia_ejecutada": True,
            "prediccion": resultado_ia_general,
            "confianza": f"{porcentaje_confianza_general:.2f}%",
            "confianza_valor": porcentaje_confianza_general,
            "imagen_url": imagen_url,
            "imagen_url_local": imagen_url_local,
            "imagen_base64": imagen_base64,
            "detecciones": detecciones
        }), 200

    except Exception as e:
        return jsonify({"status": "error", "message": f"Fallo en la API interna de test: {str(e)}"}), 500


if __name__ == '__main__':
    # Ejecución en el puerto asignado por el entorno (o 7860 por defecto en Hugging Face)
    port = int(os.environ.get("PORT", 7860))
    app.run(host='0.0.0.0', port=port, debug=True)