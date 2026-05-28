# {{REPO_NAME}}

{{DESCRIPTION}}

Servicio .NET de negocio del bounded context `{{BC_KEY}}`. Creado vía el golden
path de `Cosmos-SincoERP/.github` (arquetipo `dotnet-service`).

## CI/CD scaffoldeado

| Workflow | Evento | Qué hace |
|---|---|---|
| `pr-imagen-docker.yml` | PR a `main` | tests .NET → build & push de imágenes a ACR |
| `main-deploy-dev.yml` | push a `main` | tests → build & push → deploy a Swarm (dev) |
| `pr-cierre-cleanup.yml` | PR cerrado | borra tags `pr-N` del ACR |
| `cleanup-acr-semanal.yml` | cron lunes | barrido de tags `pr-*` viejos |

Los workflows invocan los reusables de `Cosmos-SincoERP/.github`. La forma es
neutral al BC; los **valores** (ACR, KV, stack, imágenes) se completan aquí.

## Pendientes al arrancar (TODO)

1. Crear los proyectos .NET y sus `Dockerfile`.
2. Ajustar `.github/imagenes-docker.yml` con las imágenes reales.
3. Completar `deploy/stack.dev.yml` (servicios, redes, secrets, healthchecks).
4. Confirmar los `TODO({{REPO_NAME}})` en los workflows (nombres del BC).
5. Cuando existan los `Dockerfile`, registrar `docker_directories` en el manifest
   de `.github` (`bash .github/scripts/scan-repo.sh {{REPO_NAME}}`), o esperar a
   que el drift-check lo reporte.

> `main` está protegido a nivel organización: no se hace push directo, todo entra
> por PR (ADR 0002 §B.1).
