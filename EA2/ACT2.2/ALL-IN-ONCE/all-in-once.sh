#!/bin/bash
# Script para medir el tiempo total de despliegue y el Downtime total
# (interrupción de servicio) garantizado por la estrategia Recreate.

# --- Variables Requeridas ---
SERVICE_NAME=$1        # Nombre del Service (ej: duoc-app-service)
DEPLOYMENT_NAME=$2     # Nombre del Deployment principal (ej: duoc-app-deployment)
YAML_FILE=$3           # Ruta al archivo YAML de la nueva versión (ej: RECREATE/v2.yaml)
STRATEGY="recreate"    # Estrategia fija

if [ -z "$SERVICE_NAME" ] || [ -z "$DEPLOYMENT_NAME" ] || [ -z "$YAML_FILE" ]; then
    echo "Uso: $0 <NOMBRE_SERVICE> <NOMBRE_DEPLOYMENT> <RUTA_YAML>"
    echo "Ej: $0 duoc-app-service duoc-app-recreate RECREATE/v2.yaml"
    exit 1
fi

echo "--- Iniciando Despliegue de $DEPLOYMENT_NAME ($STRATEGY) ---"

# 1. INICIO DE LA MEDICIÓN GLOBAL
START_GLOBAL_TIME=$(date +%s.%N)
echo "[1] Aplicando YAML y iniciando Rollout (RECREATE)..."

# Aplicar el manifiesto (kubectl apply)
kubectl apply -f "$YAML_FILE"
APPLY_COMPLETE_TIME=$(date +%s.%N)
APPLY_DURATION=$(echo "$APPLY_COMPLETE_TIME - $START_GLOBAL_TIME" | bc)
echo "[INFO] Apply de YAML completado en: $APPLY_DURATION segundos."


# 2. ESPERAR LA URL DEL LOADBALANCER DE AWS (TIEMPO DE PROVISIONAMIENTO)
echo "[2] Esperando que AWS asigne el hostname al LoadBalancer del Service ($SERVICE_NAME)..."

LB_URL=""
START_LB_PROVISIONING=$(date +%s.%N)
for i in {1..120}; do
    LB_URL=$(kubectl get service "$SERVICE_NAME" -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ ! -z "$LB_URL" ]; then
        echo "[SUCCESS] Hostname de LoadBalancer obtenido: http://$LB_URL"
        break
    fi
    sleep 1
done

END_LB_PROVISIONING=$(date +%s.%N)
LB_PROVISIONING_DURATION=$(echo "$END_LB_PROVISIONING - $START_LB_PROVISIONING" | bc)

if [ -z "$LB_URL" ]; then
    echo "[ERROR] No se pudo obtener el Hostname del LoadBalancer después de 120 segundos."
    exit 1
fi

# 3. DETECCIÓN DE INTERRUPCIÓN (INICIO DEL DOWNTIME)
# En Recreate, la interrupción ocurre tan pronto como el Deployment elimina los Pods antiguos.
echo "[3] Monitoreando el LoadBalancer. Esperando la interrupción de servicio..."

# Loop para detectar el primer fallo (no 200 OK)
DOWNTIME_START=0
while curl -s -o /dev/null -w "%{http_code}" "http://$LB_URL" | grep "200"; do
    sleep 0.5
    # Si el servicio sigue respondiendo 200, significa que los Pods antiguos aún están vivos o
    # que la eliminación de los antiguos aún no ha comenzado.
done

# Si salimos del loop, significa que la respuesta NO es 200.
DOWNTIME_START=$(date +%s.%N)
echo "[ALERTA] Interrupción de Servicio detectada. Cronometrando Downtime."


# 4. ESPERAR DISPONIBILIDAD EXTERNA (FIN DEL DOWNTIME)
echo "[4] Esperando la respuesta 200 OK de la nueva versión (Fin del Downtime)..."

# Loop para verificar la respuesta 200 (OK) en el path raíz (/)
while ! curl -s -o /dev/null -w "%{http_code}" "http://$LB_URL" | grep "200"; do
    sleep 1
done

DOWNTIME_END=$(date +%s.%N)
DOWNTIME_DURATION=$(echo "$DOWNTIME_END - $DOWNTIME_START" | bc)

# 5. ESPERAR A QUE KUBERNETES TERMINE (ROLLOUT STATUS)
echo "[5] Verificando estado final del Rollout en Kubernetes..."

# Es necesario esperar el rollout status para asegurar que la nueva versión está estable
kubectl rollout status deployment/"$DEPLOYMENT_NAME" --timeout=300s
if [ $? -ne 0 ]; then
    echo "[ERROR] El Rollout de Kubernetes falló o superó el tiempo de espera."
    # Continuamos para reportar al menos el Downtime
fi

# 6. CALCULAR RESULTADOS FINALES

END_GLOBAL_TIME=$(date +%s.%N)
TOTAL_DURATION=$(echo "$END_GLOBAL_TIME - $START_GLOBAL_TIME" | bc)


echo -e "\n--- RESULTADOS FINALES DE DESPLIEGUE (RECREATE) ---"
echo "A. Tiempo de Despliegue (Rollout) (Estimado): $TOTAL_DURATION segundos"
echo "B. Downtime (Interrupción Total del Servicio): $DOWNTIME_DURATION segundos"
echo "C1. Tiempo de Provisionamiento del LB (Solo 1ra vez): $LB_PROVISIONING_DURATION segundos"
echo "C2. Tiempo TOTAL hasta la Recuperación del Servicio: $TOTAL_DURATION segundos"