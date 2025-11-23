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

```actions/cache@v4```