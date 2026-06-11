import onnxruntime as ort
import numpy as np
from PIL import Image
from torchvision import transforms

classes = ['overripe', 'ripe', 'rotten', 'unripe']

session = ort.InferenceSession(
    "banana_ripeness.onnx",
    providers=["CPUExecutionProvider"]
)

transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor()
])

img = Image.open("foto8.webp").convert("RGB")

input_tensor = transform(img)
input_tensor = input_tensor.unsqueeze(0)
input_tensor = input_tensor.numpy()

outputs = session.run(
    None,
    {"input": input_tensor}
)

scores = outputs[0][0]

exp_scores = np.exp(scores - np.max(scores))
probs = exp_scores / exp_scores.sum()

pred = np.argmax(probs)

print("Clase:", classes[pred])
print("Confianza:", f"{probs[pred]*100:.2f}%")