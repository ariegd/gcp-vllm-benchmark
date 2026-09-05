#!/bin/bash

echo "=================================================="
echo " INICIANDO BARRIDO GLOBAL PARA GKE + GPU L4..."
echo "=================================================="

# Capturar el ID del proyecto activo
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
  echo "❌ Error: No se pudo determinar el PROJECT_ID de GCP. Ejecuta 'gcloud config set project TU_PROJECT_ID' primero."
  exit 1
fi

echo " Proyecto detectado: $PROJECT_ID"

# Lista prioritaria de zonas con soporte NVIDIA L4
ZONAS_L4=(
  "europe-southwest1-a" "europe-southwest1-b" "europe-southwest1-c" # Madrid
  "europe-west1-b" "europe-west1-c" "europe-west1-d"                 # Bélgica
  "europe-west4-a" "europe-west4-b" "europe-west4-c"                 # Países Bajos
  "europe-west9-a" "europe-west9-b" "europe-west9-c"                 # París
  "europe-west3-a" "europe-west3-b"                                  # Fráncfort
  "europe-west2-a" "europe-west2-b"                                  # Londres
  "us-east4-a" "us-east4-b" "us-east4-c"                              # EE. UU. Este
  "us-central1-a" "us-central1-b" "us-central1-c" "us-central1-f"     # EE. UU. Central
)

echo -e "\n🔹 Buscando disponibilidad de GPU NVIDIA L4 para GKE..."

for ZONA in "${ZONAS_L4[@]}"; do
  echo -n " Sondeando stock L4 en $ZONA... "

  # Sondeo con imagen válida especificada
  if gcloud compute instances create test-l4-probe \
      --project=$PROJECT_ID \
      --zone=$ZONA \
      --machine-type=g2-standard-4 \
      --image-family=ubuntu-2204-lts \
      --image-project=ubuntu-os-cloud \
      --maintenance-policy=TERMINATE \
      --quiet > /dev/null 2>&1; then

      echo -e " ¡Stock L4 confirmado!"
      echo "🧹 Liberando recurso de prueba en $ZONA..."
      gcloud compute instances delete test-l4-probe --zone=$ZONA --quiet > /dev/null 2>&1

      echo -e "\n Desplegando Cluster GKE 'llm-gke-cluster' en la zona $ZONA..."
      
      if gcloud container clusters create llm-gke-cluster \
          --project=$PROJECT_ID \
          --zone=$ZONA \
          --num-nodes=1 \
          --machine-type=g2-standard-4 \
          --accelerator=type=nvidia-l4,count=1,gpu-sharing-strategy=time-sharing,max-shared-clients-per-gpu=3 \
          --workload-pool=$PROJECT_ID.svc.id.goog \
          --addons=GcePersistentDiskCsiDriver; then

          echo -e "\n ¡ÉXITO TOTAL! Cluster GKE desplegado correctamente en: $ZONA"
          
          echo -e "\n🔹 Obteniendo credenciales de kubectl..."
          gcloud container clusters get-credentials llm-gke-cluster --zone=$ZONA --project=$PROJECT_ID
          
          echo -e "\n Siguiente paso: Aplica los manifiestos con 'kubectl apply -f vllm-deployments.yaml'"
          exit 0
      else
          echo "❌ Error durante la creación del cluster GKE en $ZONA."
          gcloud container clusters delete llm-gke-cluster --zone=$ZONA --async --quiet > /dev/null 2>&1
      fi
  else
      echo "❌ Sin stock / Cuota"
  fi
done

echo -e "\n⚠️ No se encontró disponibilidad de GPUs L4 en ninguna zona. Reintenta en unos minutos."
