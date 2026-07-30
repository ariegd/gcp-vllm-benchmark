# gcp-vllm-benchmark
Comparación exhaustiva, reproducible y automatizada de rendimiento, latencia y escalabilidad entre una **Máquina Virtual clásica (Google Compute Engine)** y una **arquitectura basada en contenedores y orquestación con Kubernetes (Google Kubernetes Engine - GKE)** para el servicio e inferencia de Modelos de Lenguaje de Gran Escala (LLMs).

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![GCP](https://img.shields.io/badge/Google_Cloud-GCP-4285F4?logo=googlecloud&logoColor=white)](https://cloud.google.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-GKE-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![vLLM](https://img.shields.io/badge/Inference-vLLM-FF6F00)](https://github.com/vllm-project/vllm)
[![GuideLLM](https://img.shields.io/badge/Benchmark-GuideLLM-7B2CBF)](https://github.com/neuralmagic/guidellm)

El proyecto utiliza **vLLM** como motor de inferencia de alta eficiencia (aprovechando la gestión de memoria con PagedAttention) y **GuideLLM** como suite de generación de carga y pruebas de estrés para la extracción de métricas reales en tiempo real.

---

## Tabla de Contenidos
- [Vista General de la Arquitectura](#-vista-general-de-la-arquitectura)
- [Métricas Evaluadas](#-métricas-evaluadas)
- [Estructura del Repositorio](#-estructura-del-repositorio)
- [Requisitos Previos](#-requisitos-previos)
- [Guía de Ejecución Paso a Paso (Pasos 1 al 8)](#-guía-de-ejecución-paso-a-paso-pasos-1-al-8)
  - [Paso 1: Preparación del Entorno y Credenciales](#paso-1-preparación-del-entorno-y-credenciales)
  - [Paso 2: Despliegue de Infraestructura en VM (Compute Engine)](#paso-2-despliegue-de-infraestructura-en-vm-compute-engine)
  - [Paso 3: Despliegue de Infraestructura en Kubernetes (GKE)](#paso-3-despliegue-de-infraestructura-en-kubernetes-gke)
  - [Paso 4: Pruebas de Carga Unitarias (Línea de Base)](#paso-4-pruebas-de-carga-unitarias-línea-de-base)
  - [Paso 5: Pruebas de Estrés Progresivo y Saturación (Sweep Test)](#paso-5-pruebas-de-estrés-progresivo-y-saturación-sweep-test)
  - [Paso 6: Evaluación de Escalabilidad Horizontal (GKE Multi-Pod)](#paso-6-evaluación-de-escalabilidad-horizontal-gke-multi-pod)
  - [Paso 7: Consolidación de Métricas y Generación del Reporte](#paso-7-consolidación-de-métricas-y-generación-del-reporte)
  - [Paso 8: Limpieza y Destrucción Segura de Recursos](#paso-8-limpieza-y-destrucción-segura-de-recursos)
- [Parámetros Críticos de Configuración en vLLM](#-parámetros-críticos-de-configuración-en-vllm)
- [Licencia y Autoría](#-licencia-y-autoría)

---

## Vista General de la Arquitectura

```text
                       +-----------------------------------+
                       |    Nodo de Control / Client       |
                       |       (GuideLLM Benchmark)        |
                       +-----------------+-----------------+
                                         |
                       +-----------------+-----------------+
                       |                                   |
                       v                                   v
       +---------------+---------------+   +---------------+---------------+
       |   Compute Engine VM (L4 GPU)  |   |    GKE LoadBalancer Service   |
       |  +-------------------------+  |   |  +-------------------------+  |
       |  | Docker Container (vLLM) |  |   |  | Pod 1 (vLLM) / L4 GPU   |  |
       |  |  Meta-Llama-3-8B        |  |   |  +-------------------------+  |
       |  +-------------------------+  |   |  | Pod 2 (vLLM) / L4 GPU   |  |
       +-------------------------------+   |  +-------------------------+  |
                                           +-------------------------------+
```

---

## Métricas Evaluadas

* **TTFT (Time to First Token) [ms] ⬇️:** Tiempo desde el envío de la solicitud HTTP hasta la recepción del primer token. Determina la latencia percibida por el usuario.
* **ITL (Inter-Token Latency) [ms] ⬇️:** Tiempo medio transcurrido entre la generación de tokens consecutivos. Define la fluidez en la lectura de la respuesta.
* **Throughput Global [Tokens/s] ⬆️:** Volumen total de texto generado por unidad de tiempo. Mide la capacidad máxima sostenida de procesamiento bajo estrés.

---

## Estructura del Repositorio

```text
.
├── 01_prep_credentials.sh        # Configuración de variables, autenticación GCP y verificación CLI
├── 02_deploy_vm.sh               # Despliegue de VM g2-standard-4 con GPU L4 y contenedor Docker vLLM
├── 03_deploy_gke.sh              # Creación de clúster GKE, GPU Node Pool, Secret HF y Service LoadBalancer
├── 04_test_baseline.sh           # Prueba de carga constante a baja tasa (Línea de base)
├── 05_test_sweep.sh              # Pruebas de estrés y saturación incremental (Sweep mode)
├── 06_test_horizontal_scale.sh   # Escalado horizontal en GKE (2 Nodos/Pods) y prueba de stress
├── 07_generate_report.sh         # Extracción de métricas JSON y generación de gráfica con Matplotlib
├── 08_cleanup_resources.sh       # Destrucción segura y automatizada de recursos en GCP
├── LICENSE                       # Licencia del proyecto (Apache 2.0)
└── README.md                     # Documentación principal del benchmark
```

---

## Requisitos Previos

Antes de ejecutar los scripts, asegúrate de contar con:
1. **Cuenta en Google Cloud Platform (GCP)** con un proyecto activo y cuota suficiente para GPUs `Nvidia L4` (mínimo 2 GPUs en la región `us-central1`).
2. **Google Cloud SDK (`gcloud`)** y **`kubectl`** instalados y autenticados.
3. **Token de Hugging Face (`HF_TOKEN`)** con permisos de lectura para descargar el modelo `meta-llama/Meta-Llama-3-8B-Instruct`.
4. **Python 3.10+** con `matplotlib` y `numpy` instalados en el nodo de control.
5. **GuideLLM** instalado en el nodo de control:
   ```bash
   pip install guidellm
   ```

---

## Guía de Ejecución Paso a Paso (Pasos 1 al 8)

Para garantizar la reproducibilidad y evitar diferencias de configuración entre pruebas, los scripts deben ejecutarse en el orden estricto de la secuencia:

### Paso 1: Preparación del Entorno y Credenciales
Exporta tu token de Hugging Face e inicia la comprobación de credenciales y cuotas en GCP:

```bash
export HF_TOKEN="hf_xxxxxxxxxxxxxxxxxxxxxxxx"
chmod +x *.sh
./01_prep_credentials.sh
```
*Este script verifica la presencia de `gcloud` y `kubectl`, establece la región/zona objetivo (`us-central1-a`) y prepara la estructura de directorios `./results`.*

### Paso 2: Despliegue de Infraestructura en VM (Compute Engine)
Despliega el entorno monolítico tradicional en Google Compute Engine:

```bash
./02_deploy_vm.sh
```
*Acciones realizadas:*
* Provisiona una VM `g2-standard-4` con GPU NVIDIA L4.
* Configura los drivers oficiales de NVIDIA CUDA en la VM.
* Inicia el contenedor Docker `vllm/vllm-openai:latest` sirviendo el modelo en el puerto `8000`.
* Guarda la IP pública asignada en `./results/vm_ip.txt`.

### Paso 3: Despliegue de Infraestructura en Kubernetes (GKE)
Crea la arquitectura en contenedores sobre Google Kubernetes Engine:

```bash
./03_deploy_gke.sh
```
*Acciones realizadas:*
* Crea el clúster GKE `gke-llm-cluster`.
* Añade un Node Pool de GPUs con drivers gestionados (`nvidia-l4`).
* Crea el Secret `hf-secret` con las credenciales de Hugging Face.
* Despliega el manifiesto Kubernetes (`Deployment` + `Service LoadBalancer`).
* Espera la asignación de la IP pública del LoadBalancer y la almacena en `./results/gke_ip.txt`.

### Paso 4: Pruebas de Carga Unitarias (Línea de Base)
Ejecuta la prueba de concurrencia baja para medir el rendimiento nativo del hardware:

```bash
./04_test_baseline.sh
```
*Valida que en un escenario aislado (1 Pod vs. 1 VM), el overhead del runtime de contenedores en GKE es menor al 1-2%, estableciendo la paridad de rendimiento inicial.*

### Paso 5: Pruebas de Estrés Progresivo y Saturación (Sweep Test)
Somete ambos entornos a ráfagas crecientes de tráfico para determinar el punto de degradación (*knee point*):

```bash
./05_test_sweep.sh
```
*GuideLLM incrementa progresivamente las peticiones concurrentes, registrando cómo responde la VRAM y la cola de PagedAttention cuando el sistema se aproxima al límite.*

### Paso 6: Evaluación de Escalabilidad Horizontal (GKE Multi-Pod)
Demuestra el verdadero valor operativo de Kubernetes frente a la VM monolítica:

```bash
./06_test_horizontal_scale.sh
```
*Acciones realizadas:*
* Escala el Node Pool de GKE a 2 nodos con GPUs L4.
* Reconfigura las réplicas del Deployment de vLLM a 2 (`kubectl scale deployment vllm-llama3 --replicas=2`).
* Repite la prueba de estrés de GuideLLM sobre el `LoadBalancer` para evaluar la distribución de carga y la reducción de latencia.

### Paso 7: Consolidación de Métricas y Generación del Reporte
Procesa los resultados JSON de GuideLLM y genera la representación gráfica comparativa:

```bash
./07_generate_report.sh
```
*Genera la gráfica de alta resolución (`./results/graphics/benchmark_final_report.png`) comparando el TTFT P95, ITL y Throughput global entre la VM tradicional, GKE Mono-Pod y GKE Multi-Pod.*

### Paso 8: Limpieza y Destrucción Segura de Recursos
Elimina todos los recursos provisionados en GCP para evitar cargos innecesarios de facturación:

```bash
./08_cleanup_resources.sh
```
*Destruye la instancia Compute Engine, el clúster GKE, los Node Pools y los discos persistentes asociados tras solicitar confirmación al usuario.*

---

## Parámetros Críticos de Configuración en vLLM

Para maximizar el aprovechamiento del hardware en GCP, los manifiestos y contenedores utilizan los siguientes parámetros de ajuste en vLLM:

| Parámetro | Valor por Defecto | Descripción |
| :--- | :--- | :--- |
| `--gpu-memory-utilization` | `0.90` | Porcentaje de la memoria VRAM de la GPU reservado para la inferencia y bloques de PagedAttention. |
| `--max-model-len` | `4096` | Longitud máxima de secuencia soportada por petición (tokens de entrada + salida). |
| `--tensor-parallel-size` | `1` | Cantidad de GPUs a utilizar en paralelo dentro de una misma réplica del modelo. |

---

## Licencia y Autoría

* **Autor:** Ariel Gámez Díaz ([@ariegd](https://github.com/ariegd))
* **Licencia:** Distribuido bajo la Licencia **Apache 2.0**. Consulta el archivo [`LICENSE`](LICENSE) para más información.
