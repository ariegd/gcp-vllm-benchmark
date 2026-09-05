#!/bin/bash

echo "=================================================="
echo " INICIANDO BARRIDO GLOBAL DE GPUs (L4 / T4)..."
echo "=================================================="

# Lista de zonas para NVIDIA L4 (Familia G2)
ZONAS_L4=(
  "us-central1-a" "us-central1-b" "us-central1-c" 
  "us-east4-a" "us-east4-b" "us-east1-c" 
  "us-west1-a" "europe-west4-b" "europe-west4-c"
)

# Lista de zonas para NVIDIA T4 (Familia N1)
ZONAS_T4=(
  "us-central1-a" "us-central1-b" "us-east1-c" "us-east1-d" 
  "us-west1-a" "us-west1-b" "us-west2-a" 
  "europe-west1-b" "europe-west1-c" "europe-west2-b" "europe-west3-a"
)

echo -e "\n🔹 FASE 1: Buscando disponibilidad para NVIDIA L4 (g2-standard-4)..."
for ZONA in "${ZONAS_L4[@]}"; do
  echo -n " Probando L4 en $ZONA... "
  
  if gcloud compute instances create llm-server \
      --zone=$ZONA \
      --machine-type=g2-standard-4 \
      --image-family=common-cu129-ubuntu-2204-nvidia-580 \
      --image-project=deeplearning-platform-release \
      --boot-disk-size=150GB \
      --boot-disk-type=pd-balanced \
      --maintenance-policy=TERMINATE \
      --tags=http-server,https-server \
      --quiet > /dev/null 2>&1; then
      
      echo -e "\n\n ¡ÉXITO TOTAL! Instancia L4 desplegada correctamente en la zona: $ZONA"
      echo "Para conectarte ejecuta: gcloud compute ssh llm-server --zone=$ZONA"
      exit 0
  else
      echo "❌ Sin stock"
  fi
done

echo -e "\n🔹 FASE 2: Buscando disponibilidad para NVIDIA T4 (n1-standard-4)..."
for ZONA in "${ZONAS_T4[@]}"; do
  echo -n "Probando T4 en $ZONA... "
  
  if gcloud compute instances create llm-server \
      --zone=$ZONA \
      --machine-type=n1-standard-4 \
      --accelerator=count=1,type=nvidia-tesla-t4 \
      --image-family=common-cu129-ubuntu-2204-nvidia-580 \
      --image-project=deeplearning-platform-release \
      --boot-disk-size=150GB \
      --boot-disk-type=pd-balanced \
      --maintenance-policy=TERMINATE \
      --tags=http-server,https-server \
      --quiet > /dev/null 2>&1; then
      
      echo -e "\n\n ¡ÉXITO TOTAL! Instancia T4 desplegada correctamente en la zona: $ZONA"
      echo "Para conectarte ejecuta: gcloud compute ssh llm-server --zone=$ZONA"
      exit 0
  else
      echo "❌ Sin stock"
  fi
done

echo -e "\n Todas las zonas principales están saturadas en este momento. Reintenta el script en unos minutos."
