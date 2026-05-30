# {{REPO_NAME}}

{{DESCRIPTION}}

Servicio .NET de negocio del bounded context `{{BC_KEY}}`. Creado vía el golden
path de `Cosmos-SincoERP/.github` (arquetipo `dotnet-service`).

## Qué trae al crear

- Baseline de gobernanza org (rulesets, settings de merge, registro en el manifest).
- Workflows de **seguridad** (`.github/workflows/security-checks.yml`: dependency-review + secret-scan), gestionados por el sync de `.github`.
- El `.github/dependabot.yml` lo coloca y mantiene el sync/drift de `.github` (según el `stack` del manifest); no se scaffoldea acá.

## Qué falta — y quién lo agrega

El **CI/CD de build/deploy a Swarm NO viene en el scaffold**. Se agrega más tarde, una vez que existe la infra del BC (`Cosmos.{{BC_KEY}}.Infraestructura` o equivalente) y el BC está registrado en el catálogo, corriendo la skill **`/onboard-dotnet-repo`** (en `Cosmos.AgentSkills`). Esa skill descubre los Dockerfiles y proyectos reales del repo y genera:

- `.github/workflows/` (PR build & push, deploy a Swarm en `main`, cleanups de ACR)
- `.github/imagenes-docker.yml` + `.github/scripts/calcular-imagenes-afectadas.py`
- `deploy/stack.dev.yml` (servicios, redes, secrets del Key Vault)
- los health checks en `Program.cs`

## Pasos al arrancar

1. Crear los proyectos .NET y sus `Dockerfile`.
2. Cuando existan los `Dockerfile`, el drift-check de `.github` reportará `docker_directories` para el manifest (o corré `bash .github/scripts/scan-repo.sh {{REPO_NAME}}`).
3. Con la infra del BC lista, agregar el CI/CD con `/onboard-dotnet-repo`.

> `main` está protegido a nivel organización: no se hace push directo, todo entra
> por PR (ADR 0002 §B.1).
