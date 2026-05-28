# {{REPO_NAME}}

{{DESCRIPTION}}

SPA (Bun + Vite) del bounded context `{{BC_KEY}}`. Creado vía el golden path de
`Cosmos-SincoERP/.github` (arquetipo `frontend`).

## CI/CD scaffoldeado

| Workflow | Evento | Qué hace |
|---|---|---|
| `pr-tests.yml` | PR a `main` | lint + test + build (Bun) |
| `deploy.yml` | push a `main` | deploy del SPA al Storage Account estático |

## Pendientes al arrancar (TODO)

1. Inicializar el SPA (Bun + Vite) y su `package.json`.
2. Ajustar `.deploy/env.js.tmpl` con las variables de configuración runtime.
3. Sembrar los secrets `front-{{BC_KEY}}-*` en el Key Vault del BC.
4. Confirmar `storage_account_name` y `web_endpoint` en `deploy.yml` (outputs del
   repo de Infraestructura del BC).
5. El SPA debe cargar `env.js` antes del bundle (ver patrón en repos de front existentes).

> `main` está protegido a nivel organización: todo entra por PR (ADR 0002 §B.1).
