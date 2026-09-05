# Motor de inferencia vLLM con Docker.
1. Ejecutar el script bach `barrido_global.sh`. Buscar GPU disponibles en GC.
```
./barrido_global_docker.sh
```
2. Encender la Máquina Virtual con GPU
Dependiendo de la `--zone`  donde este disponible
```
gcloud compute instances start llm-server --zone=us-east1-c
```
3. Conectar mediante SSH creando un Túnel de Puerto
```
gcloud compute ssh llm-server --zone=us-east1-c --tunnel-through-iap -- -L 8000:localhost:8000
```
4. Instalar Docker y sus herramientas
```
sudo apt update
sudo apt install -y docker.io docker-compose-v2

# Dar permisos a tu usuario 
sudo usermod -aG docker $USER
```
5. Crear un archivo `docker-compose.yml` en la VM
nano docker-compose.yml
```
services:
  # -------------------------------------------------------------
  # Servidor Único: Llama 3.1 8B Instruct (Puerto 8000)
  # -------------------------------------------------------------
  vllm-llama:
    image: vllm/vllm-openai:latest
    container_name: vllm-llama-8b
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      - VLLM_USE_FLASHINFER_SAMPLER=0
      - HF_TOKEN=${HF_TOKEN:-}
    volumes:
      - hf_cache:/root/.cache/huggingface
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    command: >
      --model meta-llama/Llama-3.1-8B-Instruct
      --port 8000
      --max-model-len 8192
      --gpu-memory-utilization 0.85

volumes:
  hf_cache:
    name: huggingface_models_cache
```
6. Arrancar todo con un solo comando
```
sudo docker compose up -d
```
7. Comandos útiles para el día a día
```
# Ver el estado de los servidores e inferencias en tiempo real:
sudo docker compose logs -f

# Ver consumo de GPU dentro de la VM:
nvidia-smi

# Detener los modelos al terminar la jornada (para ahorrar recursos):
docker compose down
```
7. Tu Túnel SSH desde tu Máquina Local
```
gcloud compute ssh llm-server \
  --zone=us-east1-c  \
  --tunnel-through-iap \
  -- -L 8000:localhost:8000 -L 8001:localhost:8001
```
8. Configuración Final en VS Code (config.yaml de Continue)
```
name: Local vLLM GCP Config
version: 0.0.1
models:
  - name: vLLM Llama 3.1 8B (GCP)
    provider: openai
    model: meta-llama/Llama-3.1-8B-Instruct
    apiBase: http://localhost:8000/v1

tabAutocompleteModel:
  name: vLLM Llama 3.1 8B (GCP)
  provider: openai
  model: meta-llama/Llama-3.1-8B-Instruct
  apiBase: http://localhost:8000/v1

```
9. Para agregar un nuevo modelo. Se tiene que actualizar el fichero `docker-compose.yml` en la VM. Luego ejecutar (Una opción)
```
# 1. Detén el contenedor con error
sudo docker compose down

# 2. Levántalo de nuevo pasando tu token explícitamente en el comando:
sudo HF_TOKEN="hf_mitoken" docker compose up -d

# 3. Revisar logs de Llama 8B
sudo docker logs -f vllm-llama-8b
```
10. Actualizar config.yaml en VS Code (Continue). en este caso
```
name: Local vLLM GCP Config
version: 0.0.1
models:
  - name: vLLM Llama 3.1 8B (GCP)
    provider: openai
    model: meta-llama/Llama-3.1-8B-Instruct
    apiBase: http://localhost:8000/v1
```
11. ¿Por qué falla si es FP8?
* Overhead de PyTorch/CUDA por Contenedor: Cada contenedor de vLLM es un proceso independiente de PyTorch/CUDA. Solo por iniciar, cada contenedor reserva entre 1.2 GB y 1.5 GB de VRAM para runtime de CUDA, inicialización del framework y CUDA Graphs.
* Suma de Pesos en VRAM (24 GB de la L4):
    - vllm-chat-7b (Qwen 7B en BF16): ~14.3 GB
    - vllm-llama-8b (Llama 8B en FP8): ~8.5 GB
    - vllm-auto-1.5b (Qwen 1.5B): ~3.0 GB
    - Total solo en pesos: ~25.8 GB (Sin contar el KV Cache ni los 4.5 GB de overhead de PyTorch por los 3 procesos).
Por eso vllm-llama-8b se quedó sin memoria y dio Available KV cache memory: -1.14 GiB.
12. Eliminar instancia de VM, depende de la `--zone`
```
gcloud compute instances delete llm-server --zone=us-east1-c
```

