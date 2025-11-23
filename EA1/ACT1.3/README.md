# Parametrización de Plantillas para Reutilización CI/CD (Node.js, Docker, AWS ECR)

```bash
on:
  push:
    branches:
      - master
  release:
    types: [published]
```

```bash
if: ${{ github.event_name == 'pull_request' }}
``` 

💾 El Ciclo de Vida de la Caché en GitHub Actions

El sistema de caché en los flujos de trabajo de Integración Continua (CI) es una estrategia de optimización que reduce el tiempo de instalación de dependencias, como los node_modules.

La razón por la que la caché falla la primera vez y funciona en las ejecuciones subsiguientes se debe a la naturaleza del proceso: el sistema primero debe guardar algo antes de poder restaurarlo.

🔍 Primera Ejecución: "Cache Miss" (Fallo)

En la primera ejecución del flujo de trabajo, ocurre lo siguiente:

Búsqueda de la Clave: GitHub Actions calcula la "huella digital" (el hash) de tu archivo package-lock.json y busca en sus servidores una caché asociada a esa clave.

Resultado: Como es la primera vez que ve ese package-lock.json o la caché anterior ha expirado, no encuentra coincidencias. Esto se llama "Cache Miss".

Acción Requerida: El paso npm ci debe ejecutarse por completo. El runner tiene que descargar todas las dependencias de la red (npm registry), lo cual consume mucho tiempo.

Guardado (al Final): Una vez que todos los pasos de tu job han terminado exitosamente, GitHub Actions toma la carpeta de dependencias descargadas (~/.npm y/o node_modules), la comprime, y la guarda en sus servidores, asociándola a la clave que se buscó inicialmente.

✅ Segunda Ejecución: "Cache Hit" (Acierto)

En la segunda ejecución (si el package-lock.json no ha cambiado), el proceso se invierte:

Búsqueda de la Clave: El sistema vuelve a calcular la "huella digital" de tu package-lock.json.

Resultado: Esta vez, sí encuentra el paquete guardado al final de la primera ejecución. Esto se llama "Cache Hit".

Acción Inmediata: Antes de que comience el paso npm ci, la acción de caché restaura automáticamente la carpeta comprimida.

Ahorro de Tiempo: El paso npm ci se ejecuta, pero en lugar de descargar los paquetes de la red, los encuentra localmente y los instala en tu carpeta node_modules en cuestión de segundos, ¡lo que acelera tu pipeline enormemente!

🔑 ¿Cuándo se Rompe la Caché?

La caché se invalida y el ciclo comienza de nuevo (volviendo a un "Cache Miss") si:

Cambias package-lock.json: Esto es lo más común. Al añadir, eliminar o actualizar una dependencia, la "huella digital" (el hash) de ese archivo cambia, generando una clave diferente.

Expiración: El caché de GitHub Actions expira después de 7 días de inactividad.

Cambias la Versión de Node.js: Si pasas de Node 18 a Node 20, la clave de la caché cambia (ya que las dependencias pueden variar) y la caché anterior no se usará.
