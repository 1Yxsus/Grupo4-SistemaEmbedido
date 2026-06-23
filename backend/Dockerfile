FROM python:3.10-slim

WORKDIR /app

# Instalar dependencias del sistema necesarias para OpenCV (cv2)
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Exponer el puerto que asigna Hugging Face (por defecto es 7860)
EXPOSE 7860

# Ejecutar el servidor apuntando al puerto dinámico asignado
CMD ["python", "app.py"]
