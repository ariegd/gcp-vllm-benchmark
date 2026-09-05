## Cómo se comportan los motores en CPU
1. **Ollama / LM Studio:** Detectan automáticamente que no hay GPU instalada y conmuta todo el cómputo a la CPU de forma transparente.
2. **vLLM:** Fue diseñado nativamente para GPU, pero cuenta con soporte oficial para CPU (usando backend OpenVINO / IPEX), aunque requiere un flag de inicio (`--device cpu`).

## Comando para crear la VM CPU directamente en Madrid (`europe-southwest1-a`)
0. Utilizar proyecto en google cloud
```
gcloud config set project siemens-hybrid-sim-2026
```
1. Crear VM en Google Cloud
```shell
gcloud compute instances create llm-server-ollama-docker \
    --zone=europe-southwest1-a \
    --machine-type=n2-standard-8 \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=150GB \
    --boot-disk-type=pd-balanced \
    --tags=http-server,https-server
```
2. Conexión por SSH
Diagnóstico acertado: la máquina virtual simplemente estaba terminando la secuencia de arranque o la inicialización del agente de Google (`google-guest-agent`) para propagar las claves SSH.
```
gcloud compute ssh llm-server-ollama-docker  --zone=europe-southwest1-a
```
3. Instalar Docker en el Host (Ubuntu 22.04 LTS)
```
# 1. Descargar e instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 2. Permitir ejecutar Docker sin sudo
sudo usermod -aG docker $USER
newgrp docker
```
4. Desplegar el Contenedor de Ollama
```
docker run -d \
  --name ollama-cpu \
  --restart unless-stopped \
  -p 11434:11434 \
  -v ollama_storage:/root/.ollama \
  ollama/ollama:latest
```
5. Descargar los modelos mediante `docker exec`
```
# 1. El modelo ultrarrápido para Autocompletado y Chat rápido (~1.9 GB)
docker exec -it ollama-cpu ollama pull qwen2.5-coder:3b

# 2. El rey para Refactorización y Agente (~4.7 GB)
docker exec -it ollama-cpu ollama pull qwen2.5-coder:7b

# 3. El modelo de razonamiento general (~4.7 GB)
docker exec -it ollama-cpu ollama pull llama3.1:8b
```
6. Probar la velocidad de procesamiento de CPU
```
docker exec -it ollama-cpu ollama run qwen2.5-coder:3b "Haz una función en Python para calcular la serie Fibonacci"
```
7. Túnel SSH desde tu Terminal Local (Puerto 11434)
```
gcloud compute ssh llm-server-ollama-docker \
    --zone=europe-southwest1-a \
    -- -L 11434:localhost:11434
```
8. Configurar config.yaml en VS Code
```
name: Main Config
version: 1.0.0
schema: v1

models:
  - name: "Qwen2.5 Coder 3B (Chat Ultrarrápido)"
    provider: ollama
    model: qwen2.5-coder:3b

  - name: "Qwen2.5 Coder 7B (Código & Agente)"
    provider: ollama
    model: qwen2.5-coder:7b

  - name: "Llama 3.1 8B (Razonamiento & Docs)"
    provider: ollama
    model: llama3.1:8b

tabAutocompleteModel:
  name: "Qwen2.5 Coder 3B (Fast Tab)"
  provider: ollama
  model: qwen2.5-coder:3b
```
9. Suspender la Instancia para Ahorrar Créditos
```
gcloud compute instances suspend llm-server-ollama-docker --zone=europe-southwest1-a
```

