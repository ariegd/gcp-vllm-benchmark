## Cómo se comportan los motores en CPU
1. **Ollama / LM Studio:** Detectan automáticamente que no hay GPU instalada y conmuta todo el cómputo a la CPU de forma transparente.
2. **vLLM:** Fue diseñado nativamente para GPU, pero cuenta con soporte oficial para CPU (usando backend OpenVINO / IPEX), aunque requiere un flag de inicio (`--device cpu`).

## Comando para crear la VM CPU directamente en Madrid (`europe-southwest1-a`)
1. Crear VM en Google Cloud
```shell
gcloud compute instances create llm-server-cpu \
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
gcloud compute ssh llm-server-cpu --zone=europe-southwest1-a
```
3. Instalar Ollama en un solo comando
```
curl -fsSL https://ollama.com/install.sh | sh
```

## Para instalar y ejecutar LM Studio en una máquina virtual sin interfaz gráfica
1. Instalar la librería del sistema faltante (`libgomp1`)
```
sudo apt update && sudo apt install -y libgomp1
```
2. Instalar la CLI de LM Studio (lms)
```
curl -fsSL https://lmstudio.ai/install.sh | bash
source ~/.bashrc
lms --version
```
3. Descargar el modelo desde la terminal
```
lms get https://huggingface.co/lmstudio-community/Qwen2.5-14B-Instruct-GGUF
```
4. Verificar y Cargar el modelo
```
lms ls
```
5. Cárgalo en la RAM
```
lms load lmstudio-community/Qwen2.5-14B-Instruct-GGUF
```
6. Iniciar Servidor y Probar
```
lms server start --port 1234
```

## O si la descarga es mediante otro directorio destino de LM Studio
1. Crear el directorio de destino de LM Studio
```
mkdir -p ~/.cache/lm-studio/models/lmstudio-community/Qwen2.5-14B-Instruct-GGUF
cd ~/.cache/lm-studio/models/lmstudio-community/Qwen2.5-14B-Instruct-GGUF
```
2. Descargar el archivo GGUF con wget
```
wget -c https://huggingface.co/lmstudio-community/Qwen2.5-14B-Instruct-GGUF/resolve/main/Qwen2.5-14B-Instruct-Q4_K_M.gguf
```
3. Cargar e Iniciar en LM Studio
```
lms import Qwen2.5-14B-Instruct-Q4_K_M.gguf --user-repo lmstudio-community/Qwen2.5-14B-Instruct-GGUF
```
4. Verificar que figura en la lista
```
lms ls
```
5. Cargar el modelo en la memoria RAM
```
lms load lmstudio-community/Qwen2.5-14B-Instruct-GGUF
```
6. Iniciar el servidor API y conectar con VS Code
```
lms server start --port 1234
```
7. Desde tu ordenador local
```
gcloud compute ssh llm-server-cpu \
    --zone=europe-southwest1-a \
    -- -L 1234:localhost:1234
```


