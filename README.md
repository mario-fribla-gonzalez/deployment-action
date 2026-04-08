# Deployment Action

Acción de GitHub para automatizar el despliegue de aplicaciones.

## Descripción

Esta acción permite empaquetar y desplegar aplicaciones en distintos entornos (desarrollo, staging, producción) de forma estandarizada, soportando despliegues de artefactos, infraestructura y configuraciones.

## Parámetros de entrada

- **environment**: Entorno de despliegue (`development`, `staging`, `production`). **Obligatorio**.
- **artifact-path**: Ruta al artefacto a desplegar. **Obligatorio**.
- **deploy-script**: Script de despliegue a ejecutar (ej: `msdeploy.ps1`, `uncompress.ps1`). **Obligatorio**.
- **config-file**: Archivo de configuración para el despliegue (opcional).
- **version**: Versión del release a desplegar (opcional).

## Ejemplo de uso

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Desplegar aplicación
        uses: ./deployment-action
        with:
          environment: prod
          artifact-path: './dist/app.zip'
          deploy-script: 'msdeploy.ps1'
          config-file: './deploy/config.json'
          version: 'v1.2.3'
```
---
Devops Mario Fribla Gonzalez
