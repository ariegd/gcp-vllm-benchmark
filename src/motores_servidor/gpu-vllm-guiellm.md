# Ejecuta GuideLLM para medir el rendimiento.
1. Crear un Entorno de Python para vLLM
```
# Instalar paquetes base de Python
sudo apt update && sudo apt install -y python3-pip python3-venv

# Crear y activar el entorno virtual
python3 -m venv vllm-env
source vllm-env/bin/activate

# Actualizar pip e instalar vLLM
pip install --upgrade pip
```
2. Probar GuideLLM
```
pip install guidellm

guidellm run \
  --backend kind=openai_http,target=http://localhost:8000/v1,model=meta-llama/Llama-3.1-8B-Instruct \
  --data kind=synthetic_text,prompt_tokens=512,output_tokens=128 \
  --profile kind=concurrent \
  --override 'profile.streams' 1,2,4,8 \
  --output kind=console \
  --output kind=html,path=./results_guidellm/report.html \
  --output kind=csv,path=./results_guidellm/results.csv
```
3. Si estamos utilizando llama 
```
HF_TOKEN="hf_mitoken" guidellm run \
  --backend kind=openai_http,target=http://localhost:8000/v1,model=meta-llama/Llama-3.1-8B-Instruct \
  --data kind=synthetic_text,prompt_tokens=512,output_tokens=128 \
  --profile kind=concurrent \
  --override 'profile.streams' 1,2,4,8 \
  --output kind=console \
  --output kind=html,path=./results_guidellm/report.html \
  --output kind=csv,path=./results_guidellm/results.csv
```
4. Lanzarlo en versión "Rápida". ⏱️ ¿Qué cambiará ahora?
Con esta restricción, GuideLLM ejecutará exactamente 60 segundos por cada nivel de concurrencia (1, 2, 4 y 8 usuarios en paralelo). En 4 minutos en total habrá terminado todo el benchmark y te generará el informe completo.
```
HF_TOKEN="hf_mitoken" guidellm run \
  --backend kind=openai_http,target=http://localhost:8000/v1,model=meta-llama/Llama-3.1-8B-Instruct \
  --data kind=synthetic_text,prompt_tokens=512,output_tokens=128 \
  --profile kind=concurrent \
  --override 'profile.streams' 1,2,4,8 \
  --constraint kind=max_duration,seconds=60 \
  --output kind=console \
  --output kind=html,path=./results_guidellm/report.html \
  --output kind=csv,path=./results_guidellm/results.csv
```
---

# Una vez completado el benchmark de GuideLLM, mostrar resultados
Esta es la mejor opción porque te genera gráficas interactivas con la latencia, la aceleración por concurrencia y los gráficos de throughput.
1. Lanzar un servidor web rápido en la VM
```
cd ./results_guidellm
python3 -m http.server 8080
```
2. Conectar mediante el Túnel SSH de GCP
```
gcloud compute ssh llm-server \
  --zone=$(gcloud compute instances list --filter="name=llm-server" --format="value(zone)") \
  --tunnel-through-iap \
  -- -L 8080:localhost:8080
```
3. Abrir en el navegador
```
http://localhost:8080/report.html
```
4. (Opcional) Descargar el Informe a tu PC Local
```
gcloud compute scp zodd@llm-server:~/results_guidellm/report.html ./report_llama.html \
  --zone=$(gcloud compute instances list --filter="name=llm-server" --format="value(zone)")
```
---

# Stack de observabilidad (Prometheus + Grafana).
**Diferencia entre GuideLLM y Grafana**
* GuideLLM (report.html): Es una foto fija / informe post-mortem. Ejecuta las pruebas, calcula estadísticas consolidadas ($p50, p90, p95$) y te genera la gráfica estática al finalizar.
* Grafana (http://localhost:3000): Es un electrocardiograma en tiempo real. Muestra en vivo los picos de trabajo, la latencia y la saturación de la VRAM mientras ejecutas los benchmarks o cuando usuarios reales envían peticiones desde VS Code.
1. Crear la configuración de Prometheus (`prometheus.yml`)
```
nano prometheus.yml

# Pega exactamente
global:
  scrape_interval: 2s # Frecuencia de recolección de métricas (ideal para benchmarks)

scrape_configs:
  - job_name: 'vllm-llama'
    static_configs:
      - targets: ['vllm-llama:8000']
```
2. Fichero `docker-compose.yml` Rectificado
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

  # -------------------------------------------------------------
  # Monitorización 1: Prometheus (Recolector de Métricas)
  # -------------------------------------------------------------
  prometheus:
    image: prom/prometheus:latest
    container_name: vllm-prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  # -------------------------------------------------------------
  # Monitorización 2: Grafana (Panel Visual)
  # -------------------------------------------------------------
  grafana:
    image: grafana/grafana:latest
    container_name: vllm-grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana

volumes:
  hf_cache:
    name: huggingface_models_cache
  grafana_data:
```
3. Reiniciar el Entorno en GCP
```
sudo HF_TOKEN="hf_mitoken" docker compose up -d
```
4. Redirección de Puertos desde tu PC Local
```
gcloud compute ssh llm-server \
  --zone=$(gcloud compute instances list --filter="name=llm-server" --format="value(zone)") \
  --tunnel-through-iap \
  -- -L 8000:localhost:8000 -L 3000:localhost:3000 -L 9090:localhost:9090
```
5. Configuración de Grafana en el Navegador
En tu ordenador local, abre el navegador e ingresa a: http://localhost:3000

Vincular Prometheus:
- Ve al menú lateral izquierdo: Connections > Data Sources.
- Haz clic en Add data source y selecciona Prometheus.
- En la casilla Prometheus server URL, escribe: http://prometheus:9090
- Haz clic abajo en Save & Test (debe mostrar un mensaje verde de confirmación).
