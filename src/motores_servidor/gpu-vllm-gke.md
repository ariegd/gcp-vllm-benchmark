# Crear el Cluster en GKE con GPU Time-Sharing
Paso a Google Kubernetes Engine (GKE). Dar este salto nos permite orquestar de forma profesional el ciclo de vida de los Pods, escalar, y compartir hardware de manera eficiente.
1. Crear el Cluster en GKE con GPU Time-Sharing
```
./barrido_gke.sh
```
2. Contexto local (como K3s, Minikube o Docker Desktop) en lugar del contexto de GKE.
```
# 1. Forzar que KUBECONFIG apunte al archivo estándar de tu usuario
export KUBECONFIG=$HOME/.kube/config

# 2. Volver a pedir las credenciales a GCP para consolidar el fichero
gcloud container clusters get-credentials llm-gke-cluster --zone=europe-west4-a

#3. Verificar la salud del nodo
kubectl get nodes
```
3. Crear el Secret para Hugging Face
```
kubectl create secret generic hf-secret \
  --from-literal=HF_TOKEN="hf_mitoken"
```
4. Crear los Manifiestos de Kubernetes (`vllm-deployments.yaml`)
Fíjate cómo los porcentajes de memoria GPU (gpu-memory-utilization) suman $0.38 + 0.38 + 0.15 = 0.91$ (91% total de los 24 GB de la L4), evitando bloqueos por falta de memoria.
```
....
```
5. Desplegar y Verificar
```
# 1. Aplicar los manifiestos: 
kubectl apply -f vllm-deployments.yaml

#2. Comprobar el estado de los Pods:
kubectl get pods -w

#3. Ver logs de un modelo específico (ej. Llama 8B):
kubectl logs -f deployment/vllm-llama-8b
```
6. En principio entre tantas pruebas, solamente se pudo ejecutar un modelo. **Nota: Que puede crear confución no esperar que arranquen los modelos del todo**
Para probar liberar puertos volver a cargar y conectar
```
# Reconectar Puertos Locales
# Matar procesos de port-forward previos y liberar sockets
pkill -f "kubectl port-forward"
fuser -k 8000/tcp 2>/dev/null

# Lanzar la redirección del puerto 8000
kubectl port-forward svc/vllm-llama-service 8000:8000 &
```

6. Conectar desde tu Máquina Local a GKE
Realizarlo en la terminal que se ejecutó el paso "2. Contexto local (como K3s, Minikube o Docker Desktop) en lugar del contexto de GKE."
```
# Lanzar port-forwards en segundo plano o terminales separadas
kubectl port-forward svc/vllm-llama-service 8000:8000 &
kubectl port-forward svc/vllm-qwen7b-service 8001:8001 &
kubectl port-forward svc/vllm-qwen1-5b-service 8002:8002 &
```
7. Configuración en VS Code (config.yaml de Continue):
```
name: GKE vLLM Cluster Config
version: 0.0.1
models:
  - name: Llama 3.1 8B FP8 (GKE)
    provider: openai
    model: neuralmagic/Meta-Llama-3.1-8B-Instruct-FP8
    apiBase: http://localhost:8000/v1

  - name: Qwen2.5 Coder 7B FP8 (GKE)
    provider: openai
    model: Qwen/Qwen2.5-Coder-7B-Instruct-FP8
    apiBase: http://localhost:8001/v1

tabAutocompleteModel:
  name: Qwen2.5 Coder 1.5B Autocomplete (GKE)
  provider: openai
  model: Qwen/Qwen2.5-Coder-1.5B-Instruct
  apiBase: http://localhost:8002/v1
```
