import os
import json
import io
import hashlib
import hmac
from datetime import datetime
import numpy as np
import onnxruntime as ort
from PIL import Image
from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import credentials, db
import requests

app = Flask(__name__)

@app.route('/')
def health_check():
    return jsonify({
        "status": "ok",
        "message": "API activa"
    }), 200

# ==========================================
# 1. CONFIGURACIÓN E INICIALIZACIÓN DE IA (ONNX)
# ==========================================

# Clases exactas de tu modelo
classes = ['overripe', 'ripe', 'rotten', 'unripe']

print("Cargando modelo ONNX...")
try:
    # Buscar el archivo .onnx en lugar del .pth
    MODEL_PATH = os.environ.get(
        "MODEL_PATH",
        os.path.join(os.path.dirname(__file__), "banana_ripeness.onnx")
    )
    
    # Inicializar la sesión de ONNX Runtime
    ort_session = ort.InferenceSession(MODEL_PATH)
    
    # Obtener el nombre de la capa de entrada requerida por el modelo
    input_name = ort_session.get_inputs()[0].name
    print("¡Modelo ONNX cargado exitosamente!")
except Exception as e:
    print(f"Error crítico al cargar el modelo de IA: {e}")
    ort_session = None

def preprocess_image(img):
    """
    Replica matemáticamente las transformaciones de PyTorch:
    transforms.Resize((224, 224)) + transforms.ToTensor()
    """
    # 1. Redimensionar imagen
    img = img.resize((224, 224))
    
    # 2. Convertir a matriz NumPy y escalar píxeles de [0, 255] a [0.0, 1.0]
    img_array = np.array(img, dtype=np.float32) / 255.0
    
    # 3. Cambiar el formato de (Alto, Ancho, Canales) a (Canales, Alto, Ancho)
    img_array = np.transpose(img_array, (2, 0, 1))
    
    # 4. Añadir la dimensión del lote (Batch) para que quede (1, C, H, W)
    img_array = np.expand_dims(img_array, axis=0)
    
    return img_array

def softmax(x):
    """Calcula las probabilidades softmax a partir de los logits nativos"""
    e_x = np.exp(x - np.max(x))
    return e_x / e_x.sum(axis=1, keepdims=True)


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
# 3. ENDPOINT EXCLUSIVO PARA INFERENCIA DE IMÁGENES
# ==========================================

@app.route('/api/data', methods=['POST'])
def recibir_datos_iot():
    try:
        if ort_session is None:
            return jsonify({"status": "error", "message": "El modelo de IA no está disponible en el servidor"}), 500

        # A. Captura de la imagen enviada por el ESP32-CAM
        # Preferimos bytes crudos (request.data), pero dejamos fallback a multipart por compatibilidad.
        img_bytes = request.data
        if not img_bytes and 'image' in request.files:
            img_bytes = request.files['image'].read()

        if not img_bytes:
            return jsonify({"status": "error", "message": "Imagen vacía o ausente en la petición"}), 400

        img = Image.open(io.BytesIO(img_bytes)).convert("RGB")

        timestamp_actual = datetime.now().strftime("%d/%m/%y %H:%M")
        public_id = f"esp32cam/{timestamp_actual.replace('/', '-').replace(' ', '_').replace(':', '-') }"

        imagen_url = None
        imagen_public_id = None
        try:
            cloudinary_result = upload_image_to_cloudinary(img_bytes, public_id)
            imagen_url = cloudinary_result.get("secure_url")
            imagen_public_id = cloudinary_result.get("public_id")
        except Exception as cloudinary_error:
            print(f"Error al subir imagen a Cloudinary: {cloudinary_error}")

        # Aplicar el preprocesamiento manual (NumPy)
        input_tensor = preprocess_image(img)

        # B. Inferencia con ONNX Runtime
        # Pasamos el tensor preparado usando el nombre de entrada dinámico
        outputs = ort_session.run(None, {input_name: input_tensor})
        logits = outputs[0] # Resultados crudos (Logits)
        
        # Calcular probabilidades softmax
        probs = softmax(logits)
        
        # Obtener el índice de la clase ganadora y su confianza
        predicted_idx = np.argmax(probs, axis=1)[0]
        confidence_val = probs[0][predicted_idx]

        # Extraer resultados
        resultado_ia = classes[predicted_idx]
        porcentaje_confianza = float(confidence_val * 100)

        # ==========================================
        # 4. REGISTRO DEL VEREDICTO EN FIREBASE
        # ==========================================
        
        # Nodo: Historial de Madurez con IA
        historial_data = {
            'fecha_hora': timestamp_actual,
            'lote': 'Lote_Campoy_Alpha',
            'estado_maduracion': resultado_ia,
            'confianza': f"{porcentaje_confianza:.2f}%",
            'imagen_url': imagen_url,
            'imagen_public_id': imagen_public_id,
        }
        db.reference('/historial_ia').push(historial_data)

        # Responder al ESP32-CAM
        return jsonify({
            "status": "success",
            "message": "Imagen procesada y clasificada en Firebase exitosamente",
            "ia_ejecutada": True,
            "prediccion": resultado_ia,
            "confianza": f"{porcentaje_confianza:.2f}%",
            "confianza_valor": porcentaje_confianza,
            "imagen_url": imagen_url,
            "imagen_public_id": imagen_public_id
        }), 200

    except Exception as e:
        return jsonify({"status": "error", "message": f"Fallo en la API interna: {str(e)}"}), 500


if __name__ == '__main__':
    # Ejecución local en el puerto 5000
    app.run(host='0.0.0.0', port=5000, debug=True)