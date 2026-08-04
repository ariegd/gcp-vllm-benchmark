#!/bin/bash
set -e

echo "=== [PASO 2] Despliegue de Infraestructura vLLM CPU Optimizada (Compute Engine) ==="

VM_NAME="vllm-vm-benchmark"
ZONE="${ZONE:-europe-southwest1-a}"

# 1. Crear regla de Firewall GCP para el puerto 8000
if ! gcloud compute firewall-rules describe allow-vllm-8000 >/dev/null 2>&1; then
    echo "--> Creando regla de firewall 'allow-vllm-8000' en GCP..."
    gcloud compute firewall-rules create allow-vllm-8000 \
        --direction=INGRESS \
        --priority=1000 \
        --network=default \
        --action=ALLOW \
        --rules=tcp:8000 \
        --source-ranges=0.0.0.0/0 \
        --description="Permitir trafico entrante para la API vLLM"
else
    echo "--> Regla de firewall 'allow-vllm-8000' ya existente."
fi

# 2. Crear la instancia Compute Engine
if ! gcloud compute instances describe $VM_NAME --zone=$ZONE >/dev/null 2>&1; then
    echo "--> Creando instancia Compute Engine e2-standard-4 (50GB SSD) en $ZONE..."
    gcloud compute instances create $VM_NAME \
        --zone=$ZONE \
        --machine-type=e2-standard-4 \
        --boot-disk-size=50GB \
        --boot-disk-type=pd-ssd \
        --image-family=ubuntu-2204-lts \
        --image-project=ubuntu-os-cloud
else
    echo "--> La instancia $VM_NAME ya existe en $ZONE."
fi

# 3. Esperar disponibilidad de SSH
echo "--> Esperando disponibilidad de la conexión SSH..."
sleep 15

MAX_ATTEMPTS=30
ATTEMPT=1
SSH_READY=0

set +e
while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "    Intento $ATTEMPT/$MAX_ATTEMPTS: Comprobando conexión SSH..."
    gcloud compute ssh $VM_NAME --zone=$ZONE --command="echo 'SSH Ready'" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "--> Conexión SSH lista."
        SSH_READY=1
        break
    fi
    sleep 5
    ATTEMPT=$((ATTEMPT + 1))
done
set -e

if [ $SSH_READY -eq 0 ]; then
    echo "❌ ERROR: No se pudo conectar por SSH a la VM."
    exit 1
fi

# 4. Generar script de instalación remota con reglas UFW y V0 Engine
cat << EOF > ./setup_vm_internal.sh
#!/bin/bash
set -e

echo "--> Instalando y configurando Docker y UFW..."
sudo apt-get update && sudo apt-get install -y docker.io curl
sudo systemctl start docker

# Permitir tráfico en el firewall interno de la VM
sudo ufw allow 8000/tcp || true

echo "--> Descargando e iniciando contenedor oficial vLLM CPU optimizado..."
sudo docker rm -f vllm-server 2>/dev/null || true

sudo docker run -d \
  --name vllm-server \
  --restart unless-stopped \
  --ipc=host \
  --security-opt seccomp=unconfined \
  -p 8000:8000 \
  -e HF_TOKEN="${HF_TOKEN}" \
  -e OMP_NUM_THREADS=2 \
  -e MKL_NUM_THREADS=2 \
  vllm/vllm-openai-cpu:latest-x86_64 \
  Qwen/Qwen2.5-0.5B-Instruct \
  --port 8000 \
  --max-model-len 256 \
  --max-num-seqs 1 \
  --gpu-memory-utilization 0.3 \
  --dtype float32 \
  --enforce-eager

echo "--> Esperando a que el servidor vLLM inicialice el modelo en CPU (tomará ~90s)..."
MAX_WAIT=180
WAIT_TIME=0
READY=0

set +e
while [ \$WAIT_TIME -lt \$MAX_WAIT ]; do
    if curl -s http://localhost:8000/v1/models | grep -q "Qwen2.5-0.5B-Instruct"; then
        READY=1
        break
    fi
    sleep 5
    WAIT_TIME=\$((WAIT_TIME + 5))
    echo "    Esperando inicialización de API (\$WAIT_TIME/\$MAX_WAIT s)..."
done
set -e

if [ \$READY -eq 1 ]; then
    echo "--> API de vLLM respondiendo correctamente en el puerto 8000."
else
    echo " ERROR: El servidor vLLM no estuvo listo a tiempo. Logs del contenedor:"
    sudo docker logs --tail 30 vllm-server
    exit 1
fi
EOF

# 5. Enviar y ejecutar el script dentro de la VM
echo "--> Enviando script de despliegue a la VM..."
gcloud compute scp ./setup_vm_internal.sh $VM_NAME:~/setup_vm_internal.sh --zone=$ZONE

echo "--> Ejecutando despliegue de vLLM en la VM..."
gcloud compute ssh $VM_NAME --zone=$ZONE --command="bash ~/setup_vm_internal.sh"

# Limpieza del script interno local
rm -f ./setup_vm_internal.sh

# 6. Obtener y guardar la IP pública dinámica de la VM
mkdir -p ./results
VM_IP=$(gcloud compute instances describe $VM_NAME --zone=$ZONE --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
echo $VM_IP > ./results/vm_ip.txt

echo "=================================================================="
echo "✅ [PASO 2 COMPLETADO] Despliegue en VM finalizado y verificado."
echo "--> IP pública registrada en ./results/vm_ip.txt: $VM_IP"
echo "--> Verificación externa desde equipo local:"
echo "    curl --connect-timeout 5 http://\$(cat ./results/vm_ip.txt):8000/v1/chat/completions \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"model\": \"Qwen/Qwen2.5-0.5B-Instruct\", \"messages\": [{\"role\": \"user\", \"content\": \"Test\"}], \"max_tokens\": 20}'"
echo "=================================================================="
