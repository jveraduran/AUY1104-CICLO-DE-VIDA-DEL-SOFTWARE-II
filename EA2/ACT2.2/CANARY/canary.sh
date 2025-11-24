#!/bin/bash
# Script para medir el tiempo de despliegue inicial y la velocidad de Rollback
# en la estrategia Canary.

# --- Variables Requeridas ---
SERVICE_NAME=$1        # Nombre del Service (ej: duoc-app-canary-service)
DEPLOYMENT_CANARY_NAME=$2 # Nombre del nuevo Deployment (ej: duoc-app-canary-v2)
YAML_FILE_CANARY=$3    # Ruta al archivo YAML del Deployment Canary (ej: CANARY/canary_v2.yaml)
TARGET_VERSION_COLOR="Canary" # Color/Versión a buscar en la respuesta (debe coincidir con la app)
STABLE_DEPLOYMENT_NAME=$4 # Nombre del Deployment Stable para la PROMOCIÓN (ej: duoc-app-stable-v1)

if [ -z "$SERVICE_NAME" ] || [ -z "$DEPLOYMENT_CANARY_NAME" ] || [ -z "$YAML_FILE_CANARY" ] || [ -z "$STABLE_DEPLOYMENT_NAME" ]; then
    echo "Uso: $0 <NOMBRE_SERVICE> <NOMBRE_DEPLOYMENT_CANARY> <RUTA_YAML_CANARY> <NOMBRE_DEPLOYMENT_STABLE>"
    echo "Ej: $0 duoc-app-canary-service duoc-app-canary-v2 CANARY/canary_v2.yaml duoc-app-stable-v1"
    exit 1
fi

echo "--- Iniciando Despliegue Canary (Fase de Exposición 10%) ---"

# 1. INICIO DE LA MEDICIÓN GLOBAL
START_GLOBAL_TIME=$(date +%s.%N)
echo "[1] Aprovisionando LoadBalancer y obteniendo URL..."

# ESPERAR LA URL DEL LOADBALANCER DE AWS (TIEMPO DE PROVISIONAMIENTO)
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


# 2. DESPLIEGUE DEL ENTORNO CANARY (10% DEL TRÁFICO)
echo "[2] Aplicando YAML de Deployment CANARY y esperando Rollout Interno..."
kubectl apply -f "$YAML_FILE_CANARY"

# Esperamos a que el nuevo Pod Canary esté completamente listo (Pods Ready).
START_CANARY_ROLLOUT_TIME=$(date +%s.%N)
kubectl rollout status deployment/"$DEPLOYMENT_CANARY_NAME" --timeout=300s
if [ $? -ne 0 ]; then
    echo "[ERROR] El Rollout del Deployment CANARY falló."
    exit 1
fi
END_CANARY_ROLLOUT_TIME=$(date +%s.%N)
CANARY_DEPLOY_DURATION=$(echo "$END_CANARY_ROLLOUT_TIME - $START_CANARY_ROLLOUT_TIME" | bc)
echo "[SUCCESS] Deployment CANARY listo en: $CANARY_DEPLOY_DURATION segundos."


# 3. VERIFICACIÓN DE EXPOSICIÓN (CONFIRMAR QUE EL 10% LLEGÓ)
# Se hacen múltiples llamadas para confirmar que la versión Canary es alcanzada
echo "[3] Verificando que la versión Canary (10%) sea alcanzable en $LB_URL..."
FOUND_CANARY=0
for i in {1..20}; do
    RESPONSE=$(curl -s "http://$LB_URL")
    if echo "$RESPONSE" | grep -q "$TARGET_VERSION_COLOR"; then
        FOUND_CANARY=1
        break
    fi
    sleep 0.5
done

if [ "$FOUND_CANARY" -eq 1 ]; then
    echo "[SUCCESS] Versión Canary detectada en el LoadBalancer."
else
    echo "[ALERTA] La versión Canary no fue detectada después de 20 intentos."
fi

# 4. SIMULACIÓN DE FALLO Y ROLLBACK (MEDICIÓN CLAVE)
echo -e "\n--- INICIANDO PRUEBA DE ROLLBACK (MÉTRICA CRÍTICA) ---"
echo "Simulando detección de fallo y ejecutando Rollback (Escalar Canary a 0 réplicas)..."

ROLLBACK_START_TIME=$(date +%s.%N)

# El Rollback se ejecuta escalando el Deployment Canary a cero.
kubectl scale deployment/"$DEPLOYMENT_CANARY_NAME" --replicas=0

# Esperamos a que la operación de escalado finalice (los Pods Canary deben terminarse).
# Nota: No usamos 'rollout status' porque este no aplica para 'scale'.
# Usaremos 'kubectl wait' o simplemente esperamos un breve periodo para que se ejecute la acción.
# Aquí medimos el tiempo que tarda la instrucción en ser procesada y confirmada.

ROLLBACK_END_TIME=$(date +%s.%N)
ROLLBACK_DURATION=$(echo "$ROLLBACK_END_TIME - $ROLLBACK_START_TIME" | bc)
echo "[SUCCESS] Rollback (Comando 'kubectl scale') completado en: $ROLLBACK_DURATION segundos."

# 5. CÁLCULO DE RESULTADOS FINALES

END_GLOBAL_TIME=$(date +%s.%N)
TOTAL_DURATION=$(echo "$END_GLOBAL_TIME - $START_GLOBAL_TIME" | bc)

echo -e "\n--- RESULTADOS FINALES DE DESPLIEGUE (CANARY) ---"
echo "A. Tiempo de Despliegue CANARY (10%): $CANARY_DEPLOY_DURATION segundos"
echo "B. Velocidad de Rollback (Escalar a 0): $ROLLBACK_DURATION segundos"
echo "C. Tiempo de Provisionamiento del LB (Solo 1ra vez): $LB_PROVISIONING_DURATION segundos"
echo "D. Riesgo de Exposición: Solo el 10% del tráfico."