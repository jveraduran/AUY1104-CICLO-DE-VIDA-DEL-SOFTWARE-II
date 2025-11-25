#!/bin/bash
# Script para medir el tiempo total de despliegue y el Downtime total
# (interrupción de servicio) garantizado por la estrategia Recreate.

# --- Variables Requeridas ---
SERVICE_NAME="duoc-app-service"                                   # Nombre del Service (ej: duoc-app-service)
DEPLOYMENT_NAME="duoc-app-deployment"                             # Nombre del Deployment principal (ej: duoc-app-deployment)
YAML_FILE="EA2/ACT2.2/ALL-IN-ONCE/all-in-once.yaml"               # Ruta al archivo YAML de la nueva versión
STRATEGY="recreate"                                               # Estrategia a medir (ej: rolling-update)

# Corrección de sintaxis: se eliminó el doble corchete [[
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

# --- CORRECCIÓN CLAVE: FORZAR ROLLOUT ---
# Si el YAML no cambia, Kubernetes no hace un rollout. 
# Usamos 'rollout restart' para forzar la ejecución de la estrategia RECREATE (downtime).
echo "[INFO] Forzando Rollout para garantizar ejecución de estrategia Recreate..."
kubectl rollout restart deployment/"$DEPLOYMENT_NAME" > /dev/null
# ----------------------------------------


# 2. ESPERAR LA URL DEL LOADBALANCER DE AWS (TIEMPO DE PROVISIONAMIENTO)
echo "[2] Esperando que AWS asigne el hostname al LoadBalancer del Service ($SERVICE_NAME)..."

# LÓGICA REFORZADA: Suprime errores de kubectl y usa una comprobación de cadena estricta.
LB_URL=""
START_LB_PROVISIONING=$(date +%s.%N)
# TIMEOUT DE 120 SEGUNDOS (según tu última entrada)
for i in {1..120}; do 
    # Obtenemos la URL. Redirigimos stderr a /dev/null para evitar interferencias.
    TEMP_LB_URL=$(kubectl get service "$SERVICE_NAME" -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null | tr -d '\n')
    
    # Comprobamos si la variable NO está vacía (-n comprueba que la longitud no sea cero)
    if [ -n "${TEMP_LB_URL}" ]; then
        LB_URL="${TEMP_LB_URL}"
        echo "[SUCCESS] Hostname de LoadBalancer obtenido: http://$LB_URL"
        break
    fi
    sleep 1
done

END_LB_PROVISIONING=$(date +%s.%N)
LB_PROVISIONING_DURATION=$(echo "$END_LB_PROVISIONING - $START_LB_PROVISIONING" | bc)

if [ -z "$LB_URL" ]; then
    echo "[ERROR] No se pudo obtener el Hostname del LoadBalancer después de 120 segundos."
    echo "[DIAGNÓSTICO] El fallo es de aprovisionamiento en AWS. El script falló porque la URL no se asignó."
    echo "[ACCIÓN REQUERIDA] Ejecute 'kubectl describe service $SERVICE_NAME' y revise los eventos (Events) para ver el error de AWS (ej. falta de etiquetas de subred o IAM)."
    exit 1
fi

# 3. DETECCIÓN DE INTERRUPCIÓN (INICIO DEL DOWNTIME)
# En Recreate, la interrupción ocurre tan pronto como el Deployment elimina los Pods antiguos.
echo "[3] Monitoreando el LoadBalancer. Esperando la interrupción de servicio..."

# Loop para detectar el primer fallo (no 200 OK)
DOWNTIME_START=0
# CORRECCIÓN: Se añade --connect-timeout 2 para forzar una falla rápida cuando el servicio se cae.
while curl -s --connect-timeout 2 -o /dev/null -w "%{http_code}" "http://$LB_URL" | grep "200" > /dev/null; do
    # --- SAFETY CHECK: Verificar si el despliegue ya terminó ---
    # Si el script se queda pegado aquí y el servicio responde 200, es posible que el rollout 
    # haya sido tan rápido que nos perdimos el downtime, o que ya finalizó.
    
    # Obtenemos réplicas actuales, listas y actualizadas
    REPLICAS=$(kubectl get deployment "$DEPLOYMENT_NAME" -o jsonpath='{.status.replicas}' 2>/dev/null)
    READY=$(kubectl get deployment "$DEPLOYMENT_NAME" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    UPDATED=$(kubectl get deployment "$DEPLOYMENT_NAME" -o jsonpath='{.status.updatedReplicas}' 2>/dev/null)
    
    # Valores por defecto en caso de nulo
    REPLICAS=${REPLICAS:-0}
    READY=${READY:-0}
    UPDATED=${UPDATED:-0}

    # Si todas las réplicas están listas y actualizadas, asumimos que el rollout terminó.
    # CORRECCION: Se cambia [[ ]] por [ ] para compatibilidad con sh/dash
    if [ "$REPLICAS" -gt 0 ] && [ "$READY" -eq "$REPLICAS" ] && [ "$UPDATED" -eq "$REPLICAS" ]; then
        echo "[INFO] El Deployment parece haber finalizado (Todos los pods Ready) mientras esperábamos la interrupción."
        echo "[INFO] Asumiendo que el Downtime ya pasó o fue imperceptible."
        break
    fi
    # -----------------------------------------------------------

    sleep 0.5
    # Si el servicio sigue respondiendo 200, significa que los Pods antiguos aún están vivos o ya están los nuevos.
done

# Si salimos del loop, significa que la respuesta NO es 200 (o la conexión falló) O el despliegue terminó.
DOWNTIME_START=$(date +%s.%N)
echo "[ALERTA] Interrupción de Servicio detectada (o finalizada). Cronometrando Downtime."


# 4. ESPERAR DISPONIBILIDAD EXTERNA (FIN DEL DOWNTIME)
echo "[4] Esperando la respuesta 200 OK de la nueva versión (Fin del Downtime)..."

# LÓGICA ROBUSTA: Captura explícitamente el código HTTP y espera hasta que sea 200.
while true; do
    # Capturamos el código HTTP, silenciando la salida de error
    HTTP_CODE=$(curl -s --connect-timeout 2 -o /dev/null -w "%{http_code}" "http://$LB_URL" 2>/dev/null)
    
    # Si el código HTTP es exactamente 200, rompemos el bucle.
    # CORRECCION: Se cambia [[ ]] por [ ] y == por = para compatibilidad con sh/dash
    if [ "$HTTP_CODE" = "200" ]; then
        break
    fi
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
echo "D. Downtime (Interrupción Total del Servicio): $DOWNTIME_DURATION segundos"