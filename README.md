# Benchmarking, Despliegue y Orquestación de Motores de Inferencia LLM

![CI/CD Pipeline](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=githubactions&logoColor=white)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
![vLLM GPU Engine](https://img.shields.io/badge/vLLM_Engine-v0.27+-2496ED?label=vLLM%20GPU&logo=docker&logoColor=white)
![Ollama CPU Engine](https://img.shields.io/badge/Ollama_Engine-Latest-black?label=Ollama%20CPU&logo=docker&logoColor=white)
![GKE Cluster](https://img.shields.io/badge/Orchestration-GKE--Kubernetes-326CE5?logo=kubernetes&logoColor=white)
![Observability Stack](https://img.shields.io/badge/Observability-Prometheus%20%26%20Grafana-E6522C?logo=prometheus&logoColor=white)

Este repositorio reúne la documentación técnica, manifiestos de infraestructura y scripts de automatización para desplegar, auditar y monitorizar motores de inferencia de Grandes Modelos de Lenguaje (LLMs). Cubre desde entornos locales orientados a desarrollo en CPU hasta clusters cloud de alto rendimiento sobre GPUs NVIDIA L4 en Google Cloud Platform (GCP).

---

## Tabla de Contenidos
- [Tecnologías y Stack por Capa](#tecnologías-y-stack-por-capa)
- [Arquitectura y Navegación del Proyecto](#arquitectura-y-navegación-del-proyecto)
- [Flujo Continuo Operativo](#flujo-continuo-operativo)
- [Puesta en Marcha (Entorno Táctico Completo)](#puesta-en-marcha-entorno-táctico-completo)
  - [Entorno Local (CPU)](#entorno-local-cpu)
  - [Entorno Servidor / Cloud (GPU)](#entorno-servidor--cloud-gpu)
- [Observabilidad y Benchmarking (GuideLLM + Prometheus + Grafana)](#observabilidad-y-benchmarking-guidellm--prometheus--grafana)
- [Cláusula de Exención de Responsabilidad (Disclaimer)](#cláusula-de-exención-de-responsabilidad-disclaimer)

---

## Tecnologías y Stack por Capa

| Capa / Dominio | Tecnologías y Herramientas |
| :--- | :--- |
| **Motores de Inferencia** | vLLM (`v0.27+`), Ollama, llama.cpp, LM Studio |
| **Modelos Evaluados** | Meta Llama 3.1 8B Instruct, Qwen2.5-Coder (7B / 1.5B) |
| **Contenedores y Orquestación** | Docker, Docker Compose (`v2`), Google Kubernetes Engine (GKE), K8s Manifests |
| **Infraestructura Cloud** | Google Cloud Platform (Compute Engine VM, GPUs NVIDIA L4, IAP Tunneling) |
| **Benchmarking y Estrés** | GuideLLM (`guidellm run`), vLLM Native Benchmarks |
| **Observabilidad en Tiempo Real** | Prometheus (Scraping `/metrics`), Grafana (Dashboards interactivos) |

---

## Arquitectura y Navegación del Proyecto

El proyecto está organizado en módulos según la infraestructura de destino:

* `motores_local/`: Documentación y manifiestos para inferencia local en CPU [README](.https://github.com/ariegd/gcp-vllm-benchmark/tree/master/src/motores_local/).
  * [`cpu-lm-studio.md`](https://github.com/ariegd/gcp-vllm-benchmark/tree/master/src/motores_local/cpu-lm-studio.md): Guía de configuración e inferencia visual mediante LM Studio.
  * [`cpu-ollama.md`](https://github.com/ariegd/gcp-vllm-benchmark/tree/master/src/motores_local/cpu-ollama.md): Instalación y ejecución bare-metal de Ollama en Linux.
  * [`cpu-ollama-docker.md`](https://github.com/ariegd/gcp-vllm-benchmark/tree/master/src/motores_local/cpu-ollama-docker.md): Despliegue containerizado de Ollama con Docker Compose.
  * [`cpu-ollama-gke.md`](https://github.com/ariegd/gcp-vllm-benchmark/tree/master/src/motores_local/cpu-ollama-gke.md): Despliegue de Ollama sobre clusters Kubernetes (GKE CPU).
  * [`cpu-ollama-3models.yaml`](https://github.com/ariegd/gcp-vllm-benchmark/tree/master/src/motores_local/cpu-ollama-3models.yaml): Manifiesto K8s para orquestación multi-modelo en Ollama.
* `motores_servidor/`: Infraestructura cloud, scripts Bash y despliegues GPU [README](./motores_servidor/).
  * [`gpu-vllm.md`](https://github.com/ariegd/gcp-vllm-benchmark/tree/master/src/motores_servidor/gpu-vllm.md): Guía general de arquitectura vLLM sobre GPUs NVIDIA.
  * [`gpu-vllm-docker.md`](https://github.com/ariegd/gcp-vllm-benchmark/tree/master/src/motores_servidor/gpu-vllm-docker.md): Configuración de vLLM con Docker Compose en Compute Engine.
  * [`gpu-vllm-gke.md`](https://github.com/ariegd/gcp-vllm-benchmark/tree/master/src/motores_servidor/gpu-vllm-gke.md): Despliegue distribuido de vLLM en Kubernetes con reservas GPU.
  * [`gpu-vllm-guiellm.md`](https://github.com/ariegd/gcp-vllm-benchmark/tree/master/src/motores_servidor/gpu-vllm-guiellm.md): Manual de pruebas de carga, latencia y stress con GuideLLM.
  * [`vllm-deployments.yaml`](https://github.com/ariegd/gcp-vllm-benchmark/tree/master/src/motores_servidor/vllm-deployments.yaml): Manifiesto K8s (`Deployment`, `Service`, `PVC`) para vLLM.
  * [`barrido_global.sh`](https://github.com/ariegd/gcp-vllm-benchmark/tree/master/src/motores_servidor/barrido_global.sh): Script de automatización para barrido de zona y cuotas en GCP.
  * [`barrido_global_docker.sh`](https://github.com/ariegd/gcp-vllm-benchmark/tree/master/src/motores_servidor/barrido_global_docker.sh): Automatización de despliegues Docker en Compute Engine.
  * [`barrido_gke.sh`](https://github.com/ariegd/gcp-vllm-benchmark/tree/master/src/motores_servidor/barrido_gke.sh): Script para provisión y escalado automatizado en clusters GKE.
* `motores_especializados/`: Evaluación de aceleradores de hardware propietarios (Apple Silicon MLX, TensorRT-LLM).
* [`motor_de_inferencia.md`](https://github.com/ariegd/gcp-vllm-benchmark/tree/master/src/motor_de_inferencia.md): Manual teórico sobre la mecánica de los motores LLM.

---

## Flujo Continuo Operativo

Se han evaluado tres modalidades progresivas de puesta en producción:

```text
┌─────────────────────────────────────────────────────┐
│                        MODALIDADES EVALUADAS                                                     │
├───────────────────┬──────────── ────┬───────────────┤
│     1. Bare-Metal                 │   2. Containerized        │     3. Kubernetes      │
│  (Host Directo Linux)        │   (Docker Compose)   │      (GKE Cluster)      │
└───────────────────┴────────────────┴────────────────┘
```

1. **Instalación Directa (Bare-metal):** Evaluación directa sobre el SO host para medir latencias base sin capas de virtualización.
2. **Contenedores Aislados (Docker / Docker Compose):** Estandarización de runtime con NVIDIA Container Toolkit, control de VRAM y aislamiento de dependencias.
3. **Orquestación Cloud (GKE):** Declaración de infraestructura mediante manifiestos YAML, persistencia de modelos vía `PVC` (caché de Hugging Face) y escalado horizontal.

---

## Puesta en Marcha (Entorno Táctico Completo)

### Entorno Local (CPU)
Para iniciar el servicio de Ollama containerizado en local:

```bash
cd motores_local
docker compose up -d
docker exec -it ollama ollama run qwen2.5-coder:7b
```

### Entorno Servidor / Cloud (GPU)
Para desplegar un servidor vLLM reservando el 85% de VRAM en una GPU NVIDIA L4 para Meta Llama 3.1 8B Instruct:

1. Definir el archivo `motores_servidor/docker-compose.yml`:
```yaml
services:
  vllm-llama:
    image: vllm/vllm-openai:latest
    container_name: vllm-llama-8b
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      - VLLM_USE_FLASHINFER_SAMPLER=0
      - HF_TOKEN=${HF_TOKEN}
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

2. Arrancar la pila de infraestructura:
```bash
cd motores_servidor
sudo HF_TOKEN="tu_token_huggingface" docker compose up -d
```

---
## Observabilidad y Benchmarking (GuideLLM + Prometheus + Grafana)
El stack de observabilidad permite evaluar el rendimiento y el consumo de VRAM en tiempo real:
```text
┌──────────────┐  /metrics  ┌──────────────┐  PromQL     ┌─────────────┐
│  vLLM (GCP)          │ ──────> │  Prometheus         │ ────────> │   Grafana             │
│ (Puerto 8000)       │  (Scrape)  │ (Puerto 9090)      │  (Query)         │ (Puerto 3000)   │
└──────────────┘             └──────────────┘                └─────────────┘
```

### Ejecución de Benchmark de Carga (GuideLLM)
```bash
HF_TOKEN="tu_token_huggingface" guidellm run \
  --backend kind=openai_http,target=http://localhost:8000/v1,model=meta-llama/Llama-3.1-8B-Instruct \
  --data kind=synthetic_text,prompt_tokens=512,output_tokens=128 \
  --profile kind=concurrent \
  --override 'profile.streams' 1,2,4,8 \
  --constraint kind=max_duration,seconds=60 \
  --output kind=html,path=./results_guidellm/report.html
```

### Consultas PromQL Principales para Grafana
* **Uso de KV Cache (%):** `vllm:kv_cache_usage_perc * 100`
* **Throughput Global (Tokens/s):** `sum(rate(vllm:generation_tokens_total[30s]))`
* **Peticiones en Cola (Saturación GPU):** `vllm:num_requests_waiting`
* **Latencia TTFT Promedio (ms):**
```
(rate(vllm:time_to_first_token_seconds_sum[30s]) / 
rate(vllm:time_to_first_token_seconds_count[30s])) * 1000
```

---

## Cláusula de Exención de Responsabilidad (Disclaimer)

Las configuraciones, scripts y benchmarks contenidos en este repositorio han sido desarrollados exclusivamente para fines de prueba técnica, investigación de infraestructura y validación de rendimiento. El usuario es responsable de los costes derivados del aprovisionamiento en proveedores cloud (GCP/GKE), así como del cumplimiento de los términos de licencias de los modelos utilizados.

---

## Licencia y Autoría

* **Autor:** Ariel Gámez ([@ariegd](https://github.com/ariegd))
* **Licencia:** Distribuido bajo la Licencia **Apache 2.0**. Consulta el archivo [`LICENSE`](LICENSE) para más información.
