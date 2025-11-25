# Análisis de Impacto de Despliegues

| **Métrica Clave**                                       | **Rolling Update**                | **Recreate**                     | **Blue/Green**                                 | **Canary**                            |
| :------------------------------------------------------ | :-------------------------------- | :------------------------------- | :--------------------------------------------- | :------------------------------------ |
| **Tiempo de Infraestructura (Provisionamiento del LB)** | C1. [Valor Medido]                | C1. [Valor Medido]               | F. [Valor Medido]                              | C. [Valor Medido]                     |
| **Tiempo de Despliegue Interno (Rollout K8s)**          | A. [Valor Medido] (Pods Ready)    | N/A (Se fusiona con Downtime)    | A. [Valor Medido] (Green Deploy)               | A. [Valor Medido] (Canary Deploy)     |
| **Velocidad de Switch / Rollout Activo**                | B. [Valor Medido] (Propagación)   | N/A (Switch = Downtime)          | B. [Valor Medido] (Switch patch K8s)           | N/A (El switch es gradual)            |
| **Downtime (Interrupción Total del Servicio)**          | D. 0 segundos                     | B. [Valor Medido]                | E. 0 segundos                                  | D. 0 segundos (Solo el 10% de riesgo) |
| **Velocidad de Mitigación / Rollback**                  | Alto (Depende del Rollout Status) | Alto (Requiere nuevo despliegue) | Instantáneo (B. [Valor Medido] si se revierte) | B. [Valor Medido] (Escalar a 0)       |
| **Riesgo de Exposición al Bug**                         | 100%                              | 100%                             | 0% (El entorno Blue se testea)                 | 10% (Solo la fracción Canary)         |
