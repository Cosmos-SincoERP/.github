# {{REPO_NAME}}

{{DESCRIPTION}}

Gateway nginx del bounded context `{{BC_KEY}}`. Creado vía el golden path de
`Cosmos-SincoERP/.github` (arquetipo `gateway`).

## CI/CD scaffoldeado

| Workflow | Evento | Qué hace |
|---|---|---|
| `pr-imagen-docker.yml` | PR a `main` | build & push de la imagen nginx a ACR |
| `main-deploy-dev.yml` | push a `main` | build & push → deploy a Swarm (dev) |
| `pr-cierre-cleanup.yml` | PR cerrado | borra tags `pr-N` del ACR |
| `cleanup-acr-semanal.yml` | cron lunes | barrido de tags `pr-*` viejos |

## Pendientes al arrancar (TODO)

1. Definir `nginx.conf` (upstreams y rutas hacia los servicios del BC).
2. Completar `deploy/stack.dev.yml` (redes, puertos, replicas).
3. Confirmar los `TODO({{REPO_NAME}})` en los workflows.

> `main` está protegido a nivel organización: todo entra por PR (ADR 0002 §B.1).
