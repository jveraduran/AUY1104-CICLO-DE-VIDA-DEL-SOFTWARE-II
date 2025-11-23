# 🚀 Guía de Despliegue Contínuo en AWS EKS (Docker, CLI & ECR)

Esta guía detalla los pasos de instalación de herramientas, autenticación en AWS y el despliegue de un clúster de Kubernetes (EKS) utilizando únicamente la AWS CLI.

## 1️⃣ Configuración de Entorno y Herramientas

Instalaremos las dependencias necesarias y las herramientas de línea de comandos para interactuar con Docker, Kubernetes y AWS.

### 1.1. Instalación de Docker y Componentes (Debian/Ubuntu)

Estos comandos configuran e instalan el motor Docker en su servidor Debian.

# 1. Actualizar sistema e instalar dependencias iniciales
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg lsb-release
```

# 2. Agregar clave GPG y repositorio oficial de Docker
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

# 3. Instalar Docker Engine, CLI y Buildx
```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

# 4. Verificar instalación
```bash
sudo docker version
sudo docker info
```

### 1.2. Instalación de Kubectl (Versión 1.30)
kubectl es la herramienta estándar para interactuar con el Control Plane de Kubernetes. Debe coincidir con la versión de su clúster (v1.30).

# 1. Instalar dependencias
```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
```

# 2. Agregar la clave GPG y el repositorio de Kubernetes
```bash
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL [https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key](https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key) | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

# Definir el repositorio para la versión 1.30
```bash
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] [https://pkgs.k8s.io/core:/stable:/v1.30/deb/](https://pkgs.k8s.io/core:/stable:/v1.30/deb/) /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

# 3. Instalar kubectl
```bash
sudo apt-get update
sudo apt-get install -y kubectl
```

### 1.3. Instalación de Eksctl (Opcional pero Recomendado)

# Descarga el binario oficial más reciente de eksctl
```bash
curl --silent --location "[https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname](https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname) -s)_amd64.tar.gz" | tar xz -C /tmp
```

# Mueve el binario a una ubicación en el PATH
```bash
sudo mv /tmp/eksctl /usr/local/bin
```

# Verifica la instalación
```bash
eksctl version
```

## 2️⃣ Autenticación y Configuración de AWS

Configuremos las credenciales necesarias y el repositorio de imágenes.

### 2.1. Configuración de Credenciales AWS
⚠️ Acción Requerida: Reemplace los valores TU_ACCESS_KEY_ID, TU_SECRET_ACCESS_KEY y TU_SESSION_TOKEN con sus credenciales de laboratorio.

# 1. Exportar variables de entorno de AWS
```bash
export AWS_ACCESS_KEY_ID="TU_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="TU_SECRET_ACCESS_KEY"
export AWS_SESSION_TOKEN="TU_SESSION_TOKEN"
export AWS_DEFAULT_REGION="us-east-1"
```

### 2.2. Creación y Login en ECR (Elastic Container Registry)
Crearemos el repositorio y autenticaremos Docker para poder subir la imagen.

# 1. Crear el repositorio ECR (si no existe)
```bash
aws ecr create-repository --repository-name duoc-lab
```

# 2. Autenticar Docker con ECR (Reemplaza 885869691689 con tu Account ID si es necesario)
# Este comando obtiene un token de login temporal y lo pasa a Docker. Recuerda reemplazar en el comando por tu cuenta de AWS.
```bash
aws ecr get-login-password --region us-east-1 | sudo docker login --username AWS --password-stdin [TU-CUENTA-AWS].dkr.ecr.us-east-1.amazonaws.com
```

### 2.3. Construcción, Etiquetado y Push de la Imagen
Definiremos variables de tag para mantener la imagen organizada y la subiremos al repositorio.

# Definir variables. Usamos 'latest' para el despliegue inicial.
```bash
export ACCOUNT_ID="" # Reemplaza con tu Account ID
export REGION="us-east-1"
export REPO_NAME="duoc-lab"
export LOCAL_TAG="duoc-app:latest"
export ECR_URI="$ACCOUNT_ID.dkr.ecr.$[REGION.amazonaws.com/$REPO_NAME:$LOCAL_TAG](https://REGION.amazonaws.com/$REPO_NAME:$LOCAL_TAG)"
```

# 1. Construir la imagen de Docker usando el Dockerfile en el directorio actual
```bash
sudo docker build -t $LOCAL_TAG .
echo "Imagen local construida con el tag: $LOCAL_TAG"
```

# 2. Etiquetar la imagen local con la URI completa de ECR
```bash
sudo docker tag $LOCAL_TAG $ECR_URI
echo "Imagen etiquetada como: $ECR_URI"
```

# 3. Subir (Push) la imagen a ECR
```bash
sudo docker push $ECR_URI
echo "¡Push a ECR completado! La imagen ya está disponible en $ECR_URI."
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
    --ami-type AL2023_x86_64 \
    --region us-east-1
```

## 4️⃣ Conexión y Despliegue en Kubernetes

Una vez que el clúster esté activo y los nodos se hayan unido, podemos desplegar la aplicación.

### 4.1. Configurar Conexión Kubeconfig y Verificar Nodos

# 1. Agrega el contexto del clúster a tu archivo kubeconfig local
```bash
aws eks update-kubeconfig --name duoc-eks-cluster-cli --region us-east-1
```

# 2. Verifica que los nodos estén en estado Ready (esto puede tardar unos minutos)
```bash
kubectl get nodes -o wide
```

### 4.2. Despliegue de la Aplicación
Revisa que tengas un archivo YAML (deployment.yaml o similar) que define tu Deployment y Service (LoadBalancer):

# 1. Aplicar el manifiesto de Deployment y Service
```bash
kubectl apply -f app-deployment.yaml
```

# 2. Verificar los recursos desplegados
```bash
kubectl get pods
kubectl get svc
```

### 4.3. Acceso y Verificación del Servicio
Para un servicio de tipo LoadBalancer, el acceso inicial se realiza a través de la Public DNS, que se obtiene posterior a la ejecución del comando ```kubetl get svc``` como ```ID.us-east-1.elb.amazonaws.com``` 