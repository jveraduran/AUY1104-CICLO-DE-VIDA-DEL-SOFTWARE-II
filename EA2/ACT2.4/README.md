# 🛠️ Implementación de Estrategia Integral (CI/CD en EKS)

Este documento guía la configuración y ejecución de un pipeline de GitHub Actions diseñado para implementar y medir las cuatro estrategias de despliegue (Rolling Update, Recreate, Blue/Green y Canary) en un cluster AWS EKS.

El objetivo es demostrar cómo la automatización y la estrategia seleccionada contribuyen a la **eficiencia**, **resiliencia**, y **continuidad operativa**.

---

## 1. ⚙️ Pre-requisitos y Configuración Base

Antes de ejecutar el pipeline, asegúrate de tener:

1.  **Cluster EKS Activo:** `duoc-eks-cluster-cli`.
2.  **Archivos YAML:** Todos los archivos de configuración (`k8s/`) deben estar en sus rutas correctas dentro del repositorio.
3.  **Secrets de GitHub:** Configura los siguientes *secrets* en tu repositorio para la autenticación en AWS:
    * `AWS_ACCESS_KEY_ID`
    * `AWS_SECRET_ACCESS_KEY`
    * `AWS_SESSION_TOKEN` (Opcional, si usas credenciales temporales)

---

## 2. 🚀 Instrucción de Uso del Pipeline (GitHub Actions)

El pipeline está configurado para que el usuario declare la estrategia a ejecutar mediante un campo de texto, activando solo el bloque de comandos correspondiente (Rolling Update, Recreate, Blue/Green o Canary).

### 2.1. 🧭 Flujo de Ejecución

1.  Ve a la pestaña **Actions** en tu repositorio.
2.  Selecciona el *workflow* **"Despliegue EKS - Estrategias de Rollout"**.
3.  Haz clic en **Run workflow**.
4.  En el campo **Estrategia a Ejecutar**, introduce el nombre exacto de la estrategia que deseas probar:
    * `rolling-update`
    * `recreate`
    * `blue-green`
    * `canary`
5.  Mantén o ajusta el nombre del cluster (`duoc-eks-cluster-cli`) y la región (`us-east-1`).
6.  Haz clic en **Run workflow** para iniciar el despliegue.

---

## 3. 🛠️ Análisis de Acciones Usadas (CI/CD)

El pipeline se divide en dos fases: **Autenticación/Conexión** y **Ejecución de la Estrategia**.

### 3.1. Fase de Configuración (Común a todas las Estrategias)

| Action / Comando | Propósito | Justificación Técnica |
| :--- | :--- | :--- |
| `actions/checkout@v4` | Descargar el código fuente. | Permite el acceso a los archivos YAML dentro del *runner*. |
| `aws-actions/configure-aws-credentials@v4` | Usar las credenciales inyectadas desde los *Secrets* (`AK/SK/Token`). | **Autenticación Segura** en AWS para la duración del *job*. |
| `aws-actions/eks-set-context@v4` | Generar la configuración `kubeconfig` a partir de la identidad AWS. | **Conexión al Cluster.** Habilita el uso de `kubectl` hacia el *cluster* EKS. |

### 3.2. Fases de Despliegue (Bloques Condicionales)

El bloque `if: ${{ github.event.inputs.strategy == '[nombre]' }}` asegura que solo se ejecute la lógica de la estrategia seleccionada.

| Estrategia | Comando Clave en el Pipeline | Contribución Estratégica |
| :--- | :--- | :--- |
| **Rolling Update** | `kubectl apply -f ...` | **Actualización gradual** de *Pods* V1 a V2. |
| **Recreate** | `kubectl apply -f ...` | Despliegue de **alto *downtime*** (V1 se elimina antes de crear V2). |
| **Blue/Green** | `kubectl patch service [NAME] -p '{"spec": {"selector": {"version": "green"}}}'` | **Switch Atómico (Cero *Downtime*)** después de la prueba de 120s. Garantiza un *rollback* instantáneo si falla. |
| **Canary** | `kubectl scale deployment/[NAME] --replicas=[N]` | **Promoción controlada** después de la prueba inicial. Escala V2 a 100% y V1 a 0, minimizando el riesgo de exposición a un 10%. |

---

## 4. 📝 Tarea de Documentación y Validación Final

Para completar la Actividad 2.4, debes documentar los resultados obtenidos por el pipeline, elaborando el informe técnico requerido.

### A. Resultados Requeridos para el Informe

Ejecuta el pipeline con cada una de las cuatro estrategias y registra los tiempos de ejecución.

| Métrica | Rolling Update | Recreate (All-in-once) | Blue/Green | Canary |
| :--- | :--- | :--- | :--- | :--- |
| **Tiempo de Despliegue Interno** | [Registrar] | [N/A] | [Registrar] | [Registrar] |
| **Velocidad de Switch** | [Registrar] | [N/A] | [Registrar] | [Registrar] |
| **Downtime (Interrupción Total)** | [Registrar: 0s] | [Registrar] | [Registrar: 0s] | [Registrar: 0s] |

### B. Análisis Requerido

Utilizando la tabla de resultados, el informe debe abordar:

1.  **Eficiencia:** ¿Cuál estrategia logra el despliegue funcional (Rollout K8s + Switch) más rápido?
2.  **Resiliencia:** ¿Cuál permite el *rollback* más rápido y seguro (B/G vs. Canary)?
3.  **Continuidad Operativa:** ¿Qué estrategia cumple con el requisito de Cero *Downtime*?