# 🚀 Análisis de Impacto de Despliegues

Esta guía detalla los pasos de instalación de herramientas, autenticación en AWS y el despliegue de un clúster de Kubernetes (EKS) utilizando únicamente la AWS CLI, junto con la captura de métricas importantes, para seleccionar una estrategia de despliegue.

## 1️⃣ Configuración de Entorno y Herramientas

Instalaremos las dependencias necesarias y las herramientas de línea de comandos para interactuar con Docker, Kubernetes y AWS.

### 1.1. Instalación de Docker y Componentes (Debian/Ubuntu)

Estos comandos configuran e instalan el motor Docker en su servidor Debian.

#### 1. Actualizar sistema e instalar dependencias iniciales
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg lsb-release
```

#### 2. Agregar clave GPG y repositorio oficial de Docker
```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

#### 3. Instalar Docker Engine, CLI y Buildx
```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

#### 4. Verificar instalación
```bash
sudo docker version
sudo docker info
```

### 1.2. Instalación de Kubectl (Versión 1.30)
kubectl es la herramienta estándar para interactuar con el Control Plane de Kubernetes. Debe coincidir con la versión de su clúster (v1.30).

#### 1. Instalar dependencias
```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
```

#### 2. Agregar la clave GPG y el repositorio de Kubernetes
```bash
sudo mkdir -p -m 755 /etc/apt/keyrings
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

#### Definir el repositorio para la versión 1.30
```bash
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] [https://pkgs.k8s.io/core:/stable:/v1.30/deb/](https://pkgs.k8s.io/core:/stable:/v1.30/deb/) /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

#### 3. Instalar kubectl
```bash
sudo apt-get update
sudo apt-get install -y kubectl bc
```

### 1.3. Instalación de Eksctl (Opcional pero Recomendado)

#### Descarga el binario oficial más reciente de eksctl
```bash
curl --silent --location "[https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname](https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname) -s)_amd64.tar.gz" | tar xz -C /tmp
```

#### Mueve el binario a una ubicación en el PATH
```bash
sudo mv /tmp/eksctl /usr/local/bin
```

#### Verifica la instalación
```bash
eksctl version
```

## 2️⃣ Autenticación y Configuración de AWS

Configuremos las credenciales necesarias y el repositorio de imágenes.

### 2.1. Configuración de Credenciales AWS
⚠️ Acción Requerida: Reemplace los valores TU_ACCESS_KEY_ID, TU_SECRET_ACCESS_KEY y TU_SESSION_TOKEN con sus credenciales de laboratorio.

#### 1. Exportar variables de entorno de AWS
```bash
export AWS_ACCESS_KEY_ID="TU_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="TU_SECRET_ACCESS_KEY"
export AWS_SESSION_TOKEN="TU_SESSION_TOKEN"
export AWS_DEFAULT_REGION="us-east-1"
```

### 2.2. Creación y Login en ECR (Elastic Container Registry)
Crearemos el repositorio y autenticaremos Docker para poder subir la imagen.

#### 1. Crear el repositorio ECR (si no existe)
```bash
aws ecr create-repository --repository-name duoc-lab
```

#### 2. Autenticar Docker con ECR (Reemplaza 885869691689 con tu Account ID si es necesario)
#### Este comando obtiene un token de login temporal y lo pasa a Docker. Recuerda reemplazar en el comando por tu cuenta de AWS.
```bash
aws ecr get-login-password --region us-east-1 | sudo docker login --username AWS --password-stdin [TU-CUENTA-AWS].dkr.ecr.us-east-1.amazonaws.com
```

### 2.3. Construcción, Etiquetado y Push de la Imagen
Definiremos variables de tag para mantener la imagen organizada y la subiremos al repositorio.

#### Definir variables. Usamos 'latest' para el despliegue inicial.
```bash
export ACCOUNT_ID="" # Reemplaza con tu Account ID
export REGION="us-east-1"
export REPO_NAME="duoc-lab"
export IMAGE_TAG_V1="v1.0"
export ECR_URI_V1="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:$IMAGE_TAG_V1"
export IMAGE_TAG_V2="v2.0"
export ECR_URI_V2="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:$IMAGE_TAG_V2"

echo "URI V1 (Stable/Blue): $ECR_URI_V1"
echo "URI V2 (Canary/Green): $ECR_URI_V2"
```

#### 1. Construir la imagen de Docker usando el Dockerfile en el directorio actual (Para Canary | Blue Green)

```bash
git clone https://github.com/Fundacion-Instituto-Profesional-Duoc-UC/AUY1104-CICLO-DE-VIDA-DEL-SOFTWARE-II
cd AUY1104-CICLO-DE-VIDA-DEL-SOFTWARE-II
sudo docker build -t $IMAGE_TAG_V1 --build-arg BUILD_COLOR="Blue" .
echo "Imagen local V1.0 construida con el tag: $IMAGE_TAG_V1"
sudo docker build -t $IMAGE_TAG_V2 --build-arg BUILD_COLOR="Green" .
echo "Imagen local V2.0 construida con el tag: $IMAGE_TAG_V2"
sudo docker images
```

#### 2. Etiquetar la imagen local con la URI completa de ECR
```bash
sudo docker tag $IMAGE_TAG_V1 $ECR_URI_V1
echo "Imagen V1.0 etiquetada como: $ECR_URI_V1"
sudo docker tag $IMAGE_TAG_V2 $ECR_URI_V2
echo "Imagen V2.0 etiquetada como: $ECR_URI_V2"
sudo docker images
```

#### 3. Subir (Push) la imagen a ECR
```bash
sudo docker push $ECR_URI_V1
echo "¡Push a ECR completado! V1.0 ya está disponible en $ECR_URI_V1."
sudo docker push $ECR_URI_V2
echo "¡Push a ECR completado! V2.0 ya está disponible en $ECR_URI_V2."
```

## 3️⃣ Creación de EKS con AWS CLI
Utilizaremos la CLI para crear el clúster (Control Plane) y el grupo de nodos (Worker Nodes).

⚠️ Acción Requerida: Reemplace los siguientes placeholders con los valores de su laboratorio:

```TU-ARN-AWS-LABROLE```: ARN del rol de IAM que usará EKS.

```ID-SUBNET-PRIVADA-1, ID-SUBNET-PRIVADA-2```: IDs de subredes privadas.

```ID-SUBNET-PUBLICA-1, ID-SUBNET-PUBLICA-2```: IDs de subredes públicas.

### 3.1. Crear el Control Plane de EKS

# Crea el clúster EKS (Control Plane) y espera a que esté activo (Aproximadamente 10 a 20 Minutos)
```bash
aws eks create-cluster \
    --name duoc-eks-cluster-cli \
    --role-arn "TU-ARN-AWS-LABROLE" \
    --resources-vpc-config subnetIds=ID-SUBNET-PRIVADA-1,ID-SUBNET-PRIVADA-2,endpointPublicAccess=true,endpointPrivateAccess=false \
    --kubernetes-version 1.30 \
    --region us-east-1
```
# Monitorear estado (esperar 10-15 minutos)
```bash
aws eks describe-cluster --name duoc-eks-cluster-cli --region us-east-1 --query 'cluster.status'
```

### 3.2. Crear el Grupo de Nodos (Worker Nodes)

# Crea el grupo de nodos (EC2 Instances) que alojará sus Pods
```bash
aws eks create-nodegroup \
    --cluster-name duoc-eks-cluster-cli \
    --nodegroup-name standard-workers-cli \
    --scaling-config minSize=1,maxSize=1,desiredSize=1 \
    --disk-size 20 \
    --subnets ID-SUBNET-PUBLICA-1 ID-SUBNET-PUBLICA-2 \
    --instance-types t3.small \
    --node-role "TU-ARN-AWS-LABROLE" \
    --ami-type AL2023_x86_64_STANDARD \
    --region us-east-1
```

## 4️⃣ Conexión y Despliegue en Kubernetes

Una vez que el clúster esté activo y los nodos se hayan unido, podemos desplegar la aplicación.

### 4.1. Configurar Conexión Kubeconfig y Verificar Nodos

#### 1. Agrega el contexto del clúster a tu archivo kubeconfig local
```bash
aws eks update-kubeconfig --name duoc-eks-cluster-cli --region us-east-1
```

#### 2. Verifica que los nodos estén en estado Ready (esto puede tardar unos minutos)
```bash
kubectl get nodes -o wide -w
```

### 4.2. Despliegue de la Aplicación - Rolling Update
Revisa que tengas un archivo YAML (deployment.yaml o similar) que define tu Deployment y Service (LoadBalancer). Adicionalmente, en cada manifiesto, deberás reemplazar el valor de ```$ECR_URI_V1 | $ECR_URI_V1```, por los valores de tus imagenes en ECR.

#### 1. Aplicar el manifiesto de Deployment y Service
```bash
sh EA2/ACT2.2/ROLLING-UPDATE/rolling-update.sh
kubectl delete -f EA2/ACT2.2/ROLLING-UPDATE/rolling-update.yaml
```

#### 2. Verificar los resultados de las métricas:

```bash
echo "A. Tiempo de Rollout Interno (K8s Ready): $ROLLOUT_DURATION segundos"
echo "B. Tiempo de Propagación LB (de Ready a 200 OK): $LB_PROPAGATION_DURATION segundos"
echo "C1. Tiempo de Provisionamiento del LB (Solo 1ra vez): $LB_PROVISIONING_DURATION segundos"
echo "C2. Tiempo TOTAL de Despliegue (Apply a 200 OK): $TOTAL_DURATION segundos"
echo "D. Downtime (Interrupción Total del Servicio): 0 segundos (Continuo para Rolling Update)"
```

#### 3. Acceso y Verificación del Servicio
Para un servicio de tipo LoadBalancer, el acceso inicial se realiza a través de la Public DNS, que se obtiene posterior a la ejecución del comando ```kubetl get svc``` como ```ID.us-east-1.elb.amazonaws.com``` 

### 4.3 Despliegue de la Aplicación - All-In-Once

#### 1. Aplicar el manifiesto de Deployment y Service
```bash
sh EA2/ACT2.2/ALL-IN-ONCE/all-in-once.sh
kubectl delete -f EA2/ACT2.2/ALL-IN-ONCE/all-in-once.yaml
```

#### 2. Verificar los resultados de las métricas:
```bash
echo "A. Tiempo de Despliegue (Rollout) (Estimado): $TOTAL_DURATION segundos"
echo "B. Downtime (Interrupción Total del Servicio): $DOWNTIME_DURATION segundos"
echo "C1. Tiempo de Provisionamiento del LB (Solo 1ra vez): $LB_PROVISIONING_DURATION segundos"
echo "C2. Tiempo TOTAL hasta la Recuperación del Servicio: $TOTAL_DURATION segundos"
echo "D. Downtime (Interrupción Total del Servicio): $DOWNTIME_DURATION segundos"
```

#### 3. Acceso y Verificación del Servicio
Para un servicio de tipo LoadBalancer, el acceso inicial se realiza a través de la Public DNS, que se obtiene posterior a la ejecución del comando ```kubetl get svc``` como ```ID.us-east-1.elb.amazonaws.com``` 


### 4.4 Despliegue de la Aplicación - Canary

#### 1. Aplicar el manifiesto de Deployment y Service
```bash
vi EA2/ACT2.2/CANARY/canary.yaml # Modifica primero la referencia a la imagen.
kubectl apply -f EA2/ACT2.2/CANARY/canary.yaml
sh EA2/ACT2.2/CANARY/canary.sh
```

#### 2. Verificar los resultados de las métricas:
```bash
echo "A. Tiempo de Despliegue CANARY Inicial (10%): $CANARY_DEPLOY_DURATION segundos"
echo "B. Tiempo de PROMOCIÓN E2E (Scale V2 a 100% -> Confirmación 200 OK/V2): $PROMOTION_E2E_DURATION segundos"
echo "C. Tiempo de Provisionamiento del LB (Solo 1ra vez): $LB_PROVISIONING_DURATION segundos"
echo "D. Riesgo de Exposición durante el Switch: 0 segundos (Continuidad garantizada por los Pods V2/Canary ya existentes)"
echo "E. Tiempo TOTAL (Apply Canary -> Promoción Finalizada): $TOTAL_DURATION segundos"
```

### 4.5 Despliegue de la Aplicación - Blue/Green

#### 1. Aplicar el manifiesto de Deployment y Service
```bash
vi EA2/ACT2.2/BLUE-GREEN/blue-green.yaml # Modifica primero la referencia a la imagen.
sh EA2/ACT2.2/BLUE-GREEN/blue-green.sh
```
#### 2. Verificar los resultados de las métricas:
```bash
echo "A. Tiempo de Despliegue GREEN (Deployment Interno): $GREEN_DEPLOY_DURATION segundos"
echo "B. Tiempo de ESPERA/TESTEO de 120s: $WAIT_DURATION_S segundos"
echo "C. Velocidad de Switch (kubectl patch): $SWITCH_DURATION segundos"
echo "D. Tiempo de Propagación (Patch hasta 200 OK/Green): $PROPAGATION_DURATION segundos"
echo "E. Tiempo TOTAL E2E (Apply -> Switch OK, SIN Contar Espera): $(echo "$GREEN_DEPLOY_DURATION + $SWITCH_DURATION + $PROPAGATION_DURATION" | bc) segundos"
echo "F. Uptime / Downtime: Cero Interrupción (El servicio Blue estuvo activo en todo momento)"
echo "G. Tiempo de Provisionamiento del LB (Solo 1ra vez): $LB_PROVISIONING_DURATION segundos"
```

# Tabla comparativa

| **Métrica Clave** | **Rolling Update** | **Recreate** | **Blue/Green** | **Canary** |
| :------------------------------------------------------ | :-------------------------------- | :------------------------------- | :--------------------------------------------- | :------------------------------------ |
| **Tiempo de Infraestructura (Provisionamiento del LB)** | C1. [Valor Medido]                | C1. [Valor Medido]               | G. [Valor Medido]                              | C. [Valor Medido]                     |
| **Tiempo de Despliegue Interno (Rollout K8s)** | A. [Valor Medido] (Pods Ready)    | N/A (Se fusiona con Downtime)    | A. [Valor Medido] (Green Deploy)               | A. [Valor Medido] (Canary Deploy)     |
| **Velocidad de Switch / Rollout Activo** | B. [Valor Medido] (Propagación)   | N/A (Switch = Downtime)          | C. [Valor Medido] (Switch patch K8s)           | N/A (El switch es gradual)            |
| **Downtime (Interrupción Total del Servicio)** | D. 0 segundos                     | B. [Valor Medido]                | F. 0 segundos                                  | D. 0 segundos (Solo el 10% de riesgo) |
| **Velocidad de Mitigación / Rollback** | Alto (Depende del Rollout Status) | Alto (Requiere nuevo despliegue) | Instantáneo (C. [Valor Medido] si se revierte) | B. [Valor Medido] (Escalar a 0)       |
| **Riesgo de Exposición al Bug** | 100%                              | 100%                             | 0% (El entorno Blue se testea)                 | 10% (Solo la fracción Canary)         |
