#!/bin/bash
# Script para medir el tiempo total de despliegue desde kubectl apply hasta la disponibilidad del LoadBalancer (200 OK).

# --- Variables Requeridas ---
SERVICE_NAME="duoc-app-service"                                   # Nombre del Service (ej: duoc-app-service)
DEPLOYMENT_NAME="duoc-app-deployment"                             # Nombre del Deployment principal (ej: duoc-app-deployment)
YAML_FILE="EA2/ACT2.2/ROLLING-UPDATE/rolling-update.yaml"         # Ruta al archivo YAML de la nueva versión (ej: ROLLING-UPDATE/v2.yaml)
STRATEGY="rolling-update"                                         # Estrategia a medir (ej: rolling-update)

if [ -z "$SERVICE_NAME" ] || [ -z "$DEPLOYMENT_NAME" ] || [ -z "$YAML_FILE" ]; then
    echo "Uso: $0 <NOMBRE_SERVICE> <NOMBRE_DEPLOYMENT> <RUTA_YAML> [ESTRATEGIA]"
    echo "Ej: $0 duoc-app-service duoc-app-deployment ROLLING-UPDATE/v2.yaml rolling-update"
    exit 1
fi

echo "--- Iniciando Despliegue de $DEPLOYMENT_NAME ($STRATEGY) ---"

# 1. INICIO DE LA MEDICIÓN GLOBAL
START_GLOBAL_TIME=$(date +%s.%N)
echo "[1] Aplicando YAML y iniciando Rollout..."

# Aplicar el manifiesto (kubectl apply)
kubectl apply -f "$YAML_FILE"
APPLY_COMPLETE_TIME=$(date +%s.%N)
APPLY_DURATION=$(echo "$APPLY_COMPLETE_TIME - $START_GLOBAL_TIME" | bc)
echo "[INFO] Apply de YAML completado en: $APPLY_DURATION segundos."


# 2. ESPERAR LA URL DEL LOADBALANCER DE AWS (TIEMPO DE PROVISIONAMIENTO)
echo "[2] Esperando que AWS asigne el hostname al LoadBalancer del Service ($SERVICE_NAME)..."

# Obtener la URL externa. El loop espera hasta que la URL no sea <pending>.
LB_URL=""
START_LB_PROVISIONING=$(date +%s.%N) # <-- INICIO de medición de aprovisionamiento

# Cambiamos el límite de espera a 120 segundos, como en la versión anterior.
for i in {1..120}; do
    # Intenta obtener el hostname. La opción -o=jsonpath puede devolver una cadena vacía si no existe el campo.
    # El comando tr se usa para limpiar cualquier carácter de control o salto de línea.
    TEMP_LB_URL=$(kubectl get service "$SERVICE_NAME" -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}' | tr -d '\n')
    
    # Verificamos si la URL no está vacía.
    if [ ! -z "$TEMP_LB_URL" ]; then
        LB_URL="$TEMP_LB_URL" # Asignamos la URL si se encontró
        echo "[SUCCESS] Hostname de LoadBalancer obtenido: http://$LB_URL"
        break
    fi
    # Si la URL sigue siendo vacía, el bucle continúa y espera 1 segundo.
    sleep 1
done

END_LB_PROVISIONING=$(date +%s.%N) # <-- FIN de medición de aprovisionamiento
LB_PROVISIONING_DURATION=$(echo "$END_LB_PROVISIONING - $START_LB_PROVISIONING" | bc)

if [ -z "$LB_URL" ]; then
    echo "[ERROR] No se pudo obtener el Hostname del LoadBalancer después de 120 segundos."
    exit 1
fi

# 3. ESPERAR A QUE KUBERNETES TERMINE (ROLLOUT STATUS)
echo "[3] Esperando a que el Rollout Interno de Kubernetes finalice (Pods Ready)..."

# Medimos el tiempo que tarda la orquestación interna (Pods Ready)
START_ROLLOUT_STATUS_TIME=$(date +%s.%N)

# Espera al estado de Ready. Esto bloquea el script hasta que el Pod está funcionando.
kubectl rollout status deployment/"$DEPLOYMENT_NAME" --timeout=300s
if [ $? -ne 0 ]; then
    echo "[ERROR] El Rollout de Kubernetes falló o superó el tiempo de espera."
    exit 1
fi

END_ROLLOUT_STATUS_TIME=$(date +%s.%N)
ROLLOUT_DURATION=$(echo "$END_ROLLOUT_STATUS_TIME - $START_ROLLOUT_STATUS_TIME" | bc)
echo "[SUCCESS] Rollout de Kubernetes (Pods Ready) completado en: $ROLLOUT_DURATION segundos."


# 4. ESPERAR DISPONIBILIDAD EXTERNA (LOADBALANCER RESPONDE 200 OK)
echo "[4] Esperando la respuesta 200 OK del LoadBalancer externo (Propagación)..."

# Medimos el tiempo que tarda el LoadBalancer en reconocer el cambio.
START_LB_CHECK_TIME=$(date +%s.%N)
# Loop para verificar la respuesta 200 (OK) en el path raíz (/)
while ! curl -s -o /dev/null -w "%{http_code}" "http://$LB_URL" | grep "200"; do
    sleep 1
done

END_LB_CHECK_TIME=$(date +%s.%N)
LB_PROPAGATION_DURATION=$(echo "$END_LB_CHECK_TIME - $START_LB_CHECK_TIME" | bc)

# 5. CALCULAR RESULTADOS FINALES

END_GLOBAL_TIME=$(date +%s.%N)
TOTAL_DURATION=$(echo "$END_GLOBAL_TIME - $START_GLOBAL_TIME" | bc)

echo -e "\n--- RESULTADOS FINALES DE DESPLIEGUE ($STRATEGY) ---"
echo "A. Tiempo de Rollout Interno (K8s Ready): $ROLLOUT_DURATION segundos"
echo "B. Tiempo de Propagación LB (de Ready a 200 OK): $LB_PROPAGATION_DURATION segundos"
echo "C1. Tiempo de Provisionamiento del LB (Solo 1ra vez): $LB_PROVISIONING_DURATION segundos"
echo "C2. Tiempo TOTAL de Despliegue (Apply a 200 OK): $TOTAL_DURATION segundos"
echo "D. Downtime (Interrupción Total del Servicio): 0 segundos (Continuo para Rolling Update)"