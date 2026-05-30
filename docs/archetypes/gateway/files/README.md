# {{REPO_NAME}}

{{DESCRIPTION}}

Gateway nginx del bounded context `{{BC_KEY}}`. Creado vía el golden path de
`Cosmos-SincoERP/.github` (arquetipo `gateway`).

## Qué trae al crear

- Baseline de gobernanza org (rulesets, settings de merge, registro en el manifest).
- Workflows de **seguridad** (`.github/workflows/security-checks.yml`: dependency-review + secret-scan), gestionados por el sync de `.github`.
- El skeleton de la app: `Dockerfile` + `nginx.conf` (ajustalos a los upstreams del BC).
- El `.github/dependabot.yml` lo gestiona el sync/drift de `.github`.

## Qué falta — y quién lo agrega

El **CI/CD de build/deploy a Swarm NO viene en el scaffold**. Se agrega más tarde, con la infra del BC lista, corriendo la skill **`/onboard-gateway-repo`** (en `Cosmos.AgentSkills`). Esa skill genera:

- `.github/workflows/` (PR build & push, deploy a Swarm en `main`, cleanups de ACR)
- `.github/imagenes-docker.yml` + `.github/scripts/calcular-imagenes-afectadas.py`
- `deploy/stack.dev.yml` (servicio, redes del BC, secrets del Key Vault si aplica)

(Sin job de tests ni `Program.cs`: un gateway nginx no tiene código .NET.)

## Pasos al arrancar

1. Definir `nginx.conf` (upstreams y rutas hacia los servicios del BC) y el `Dockerfile`.
2. Con la infra del BC lista, agregar el CI/CD con `/onboard-gateway-repo`.

> `main` está protegido a nivel organización: todo entra por PR (ADR 0002 §B.1).
