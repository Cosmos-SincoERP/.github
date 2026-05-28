# {{REPO_NAME}}

{{DESCRIPTION}}

Infraestructura Terraform del bounded context `{{BC_KEY}}`. Creado vía el golden
path de `Cosmos-SincoERP/.github` (arquetipo `infra`). Los `.tf` viven en `/infra`.

## CI/CD scaffoldeado

| Workflow | Evento | Qué hace |
|---|---|---|
| `pr-plan.yml` | PR a `main` | `fmt -check` + `init` + `validate` + `plan` (self-hosted, MI) |
| `main-apply.yml` | push a `main` | `init` + `apply -auto-approve` (self-hosted, MI) |

No hay reusable de Terraform en la plataforma: estos workflows son self-contained.

## Pendientes al arrancar (TODO)

1. Configurar el backend remoto (azurerm) en `infra/versions.tf`.
2. Declarar los recursos / módulos del BC en `infra/`.
3. Confirmar que el runner self-hosted del BC tiene Managed Identity con los roles
   necesarios para el `apply`.

> `main` está protegido a nivel organización: todo entra por PR (ADR 0002 §B.1).
> El `apply` corre al mergear; considerar environments con required reviewers
> cuando exista producción (ADR 0003 §D.2).
