# Arquitectura en GKE
Desplegar Ollama en Google Kubernetes Engine (GKE) asignando un Pod dedicado a cada modelo es una arquitectura de nivel profesional.

## Guía Paso a Paso: Despliegue de 3 Pods en GKE
0. Habilitar API de GKE y configurar proyecto
```
gcloud config set project siemens-hybrid-sim-2026
gcloud services enable container.googleapis.com

# Instalar el componente de autenticación gke-gcloud-auth-plugin si no lo tienes
gcloud components install gke-gcloud-auth-plugin
```
1. Crear el Clúster de GKE en Madrid (europe-southwest1-a)
```shell
# Crear clúster Standard en Madrid
gcloud container clusters create ollama-cluster \
    --zone=europe-southwest1-a \
    --num-nodes=1 \
    --machine-type=n2-standard-8 \
    --disk-size=150 \
    --disk-type=pd-balanced \
    --scopes=gke-default

# Obtener credenciales para kubectl
gcloud container clusters get-credentials ollama-cluster --zone=europe-southwest1-a
```
2. Crear el archivo de manifiestos `ollama-3models.yaml`
```
# si en el paso 3 obtenemos algún error, aplicar
export KUBECONFIG=$HOME/.kube/gke-config
gcloud container clusters get-credentials ollama-cluster --zone=europe-southwest1-a

# y comprobar
 kubectl get nodes
```
3. Aplicar el manifiesto en el Clúster
```
kubectl apply -f ollama-3models.yaml

kubectl get pods -w
```
4. Mapeo de Puertos SSH / Port-Forwarding Local
```
# Terminal 1: Redirigir Qwen 3B al puerto 11434
export KUBECONFIG=$HOME/.kube/gke-config
kubectl port-forward svc/svc-ollama-qwen-3b 11434:11434

# Terminal 2: Redirigir Qwen 7B al puerto 11435
export KUBECONFIG=$HOME/.kube/gke-config
kubectl port-forward svc/svc-ollama-qwen-7b 11435:11434

# Terminal 3: Redirigir Llama 3.1 8B al puerto 11436
export KUBECONFIG=$HOME/.kube/gke-config
kubectl port-forward svc/svc-ollama-llama-8b 11436:11434
```
5. Configurar config.yaml en VS Code
```
name: GKE Multi-Pod Config
version: 1.0.0
schema: v1

models:
  - name: "Qwen2.5 Coder 3B (Pod 1 - Fast Tab)"
    provider: ollama
    model: qwen2.5-coder:3b
    apiBase: "http://localhost:11434"

  - name: "Qwen2.5 Coder 7B (Pod 2 - Code Agent)"
    provider: ollama
    model: qwen2.5-coder:7b
    apiBase: "http://localhost:11435"

  - name: "Llama 3.1 8B (Pod 3 - Reasoning)"
    provider: ollama
    model: llama3.1:8b
    apiBase: "http://localhost:11436"

tabAutocompleteModel:
  name: "Qwen2.5 Coder 3B (Pod 1 - Fast Tab)"
  provider: ollama
  model: qwen2.5-coder:3b
  apiBase: "http://localhost:11434"
```
9. Suspender la Instancia para Ahorrar Créditos
```
gcloud compute instances suspend ollama-cluster --zone=europe-southwest1-a
```
10. Comando para borrarlas en un solo paso
```
gcloud compute instances delete llm-server-cpu llm-server-cpu-ollama llm-server-ollama-docker \
    --zone=europe-southwest1-a \
    --quiet
```
11. Eliminar el clúster fallido
```
gcloud container clusters delete ollama-cluster \
    --zone=europe-southwest1-a \
    --quiet
```
