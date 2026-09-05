# Motor de inferencia vLLM en limpio.
1. Ejecutar el script bach `barrido_global.sh`. Buscar GPU disponibles en GC.
```
./barrido_global.sh
```
2. Encender la Máquina Virtual con GPU
Dependiendo de la `--zone`  donde este disponible
```
gcloud compute instances start llm-server --zone=us-central1-b
```
3. Conectar mediante SSH creando un Túnel de Puerto
```
gcloud compute ssh llm-server --zone=us-central1-b --tunnel-through-iap -- -L 8000:localhost:8000
```
4. Aún no tiene instalados los controladores de NVIDIA ni el entorno de CUDA. (Lo más probable)
```
# 1. Actualizar repositorios e instalar dependencias básicas
sudo apt update

# 2. Instalar el driver de servidor NVIDIA 550 desde los repositorios de Ubuntu
sudo apt install -y nvidia-driver-550-server

#3 Reiniciar
sudo reboot
```
5. Crear un Entorno de Python para vLLM
```
# Instalar paquetes base de Python
sudo apt update && sudo apt install -y python3-pip python3-venv

# Crear y activar el entorno virtual
python3 -m venv vllm-env
source vllm-env/bin/activate

# Actualizar pip e instalar vLLM
pip install --upgrade pip
pip install vllm
```
6. Verificar Drivers y Arrancar vLLM
```
nvidia-smi
```
7. Aplicar un parche de 1 segundo (Recomendado)
```
sed -i '1s/^/from __future__ import annotations\n/' ~/vllm-env/lib/python3.10/site-packages/flashinfer/comm/fd_exchange.py
```
8. Si vLLM ya está instalado en el entorno de Python, ejecuta el servidor sirviendo el modelo de código:
La forma más rápida de solucionarlo es desactivar el sampler de FlashInfer para que vLLM utilice el motor de sampling nativo de PyTorch/vLLM (que no requiere compilar nada con nvcc).
```
VLLM_USE_FLASHINFER_SAMPLER=0 python3 -m vllm.entrypoints.openai.api_server \
  --model Qwen/Qwen2.5-Coder-7B-Instruct \
  --port 8000 \
  --max-model-len 8192 \
  --gpu-memory-utilization 0.85
```
9. Validar la conexión desde tu equipo local
```
curl http://localhost:8000/v1/models
```
10. Configurar el Plugin Continue en VS Code
```
models:
  - name: vLLM Qwen2.5-Coder 7B (GCP)
    provider: openai
    model: Qwen/Qwen2.5-Coder-7B-Instruct
    apiBase: http://localhost:8000/v1

tabAutocompleteModel:
  name: vLLM Qwen2.5-Coder Autocomplete
  provider: openai
  model: Qwen/Qwen2.5-Coder-7B-Instruct
  apiBase: http://localhost:8000/v1
```
11. ¿Cómo ejecutar 2 modelos simultáneamente en la misma GPU?
```
# Terminal 1 (Autocompletado ultra rápido - Puerto 8001):
# Reserva el 20% de la GPU (~4.8 GB VRAM)
VLLM_USE_FLASHINFER_SAMPLER=0 python3 -m vllm.entrypoints.openai.api_server \
  --model Qwen/Qwen2.5-Coder-1.5B-Instruct \
  --port 8001 \
  --gpu-memory-utilization 0.20
  
  # Terminal 2 (Chat y Código Avanzado - Puerto 8000):
  # Reserva el 70% de la GPU (~16.8 GB VRAM)
VLLM_USE_FLASHINFER_SAMPLER=0 python3 -m vllm.entrypoints.openai.api_server \
  --model Qwen/Qwen2.5-Coder-7B-Instruct \
  --port 8000 \
  --gpu-memory-utilization 0.70
```

