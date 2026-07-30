#!/bin/bash
set -e

echo "=== [PASO 1] Preparación del Entorno y Credenciales ==="

# Variables globales del benchmark
export PROJECT_ID=$(gcloud config get-value project)
export REGION="europe-southwest1"
export ZONE="europe-southwest1-a"

if [ -z "$HF_TOKEN" ]; then
    echo "ERROR: La variable HF_TOKEN no está definida."
    echo "Por favor ejecute: export HF_TOKEN='tu_token_de_huggingface'"
    exit 1
fi

echo "--> Configurando región y zona por defecto..."
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

echo "--> Verificando instalación de herramientas CLI locales..."
command -v gcloud >/dev/null 2>&1 || { echo "gcloud CLI no está instalado."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl no está instalado."; exit 1; }

# Crear directorio para guardar métricas y artefactos del benchmark
mkdir -p ./results

echo "✅ Paso 1 completado con éxito."
