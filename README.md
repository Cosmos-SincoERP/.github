# `.github` — Cosmos-SincoERP

Repositorio especial de la organización **Cosmos-SincoERP**. Cumple tres funciones:

1. **Defaults org-wide (community health files)**. Los archivos en este repo bajo rutas como `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/*`, `SECURITY.md`, `CODEOWNERS`, `.github/dependabot.yml` actúan como **defaults para cualquier repo de la organización que no tenga el suyo propio**.

2. **Workflows reusables org-wide** (`.github/workflows/_reusable-*.yml`). Los repos consumidores los invocan con `uses: Cosmos-SincoERP/.github/.github/workflows/_reusable-<name>.yml@v1`. Migrados desde `Cosmos.PlatformWorkflows` en mayo 2026 (ver ADR 0002 §D.7); el repo origen mantiene las skills de Claude y será renombrado a `Cosmos.AgentSkills`.

3. **Documentación de gobernanza operacional + sync automatizado**. ADRs sobre políticas de repositorios, gobierno de la organización y prácticas de plataforma en `docs/adr/`. Manifest de repos consumidores en `docs/repos-manifest.yml`. Sync workflow (`sync-governance.yml`) propaga cambios de plantillas dependabot y referencias `uses:` a los repos consumidores automáticamente.

> **Visibilidad**: este repo es **público**. Los reusables y la documentación de gobernanza no contienen información operacional sensible (ADRs son guías de decisión, no de implementación; los reusables reciben sus valores específicos por inputs). Mantenerlo público permite que Dependabot en los repos consumidores resuelva las referencias `uses: org/.github/...@v1` sin requerir PAT ni configuración adicional.

## Estructura

```
.
├── .github/
│   ├── workflows/
│   │   ├── _reusable-*.yml          # 14 reusables CI/CD compartidos (los originales migrados desde Cosmos.PlatformWorkflows)
│   │   ├── create-repo.yml          # Crea repos gobernados (baseline de seguridad)
│   │   ├── sync-governance.yml      # Propaga cambios a repos consumidores
│   │   ├── drift-check-governance.yml  # Reporta drift semanalmente
│   │   ├── release-label-check.yml  # Gate requerido: exige etiqueta de release en PRs que tocan reusables
│   │   ├── release-reusables.yml    # Tagger: mueve/crea el major (vN/v(N+1)) al mergear, según la etiqueta
│   │   └── README.md                # Doc de los reusables (catálogo + uso + versionado)
│   └── scripts/
│       ├── create-repo.sh           # Lógica de la creación de repos
│       ├── sync-governance.sh       # Lógica del sync
│       ├── drift-check-governance.sh
│       ├── scan-repo.sh             # Helper de onboarding: propone bloque manifest
│       ├── lib-scan.sh              # Heurísticas de inspección (stack, docker, terraform)
│       └── lib-render.sh            # Render compartido (dependabot, entrada de manifest)
├── docs/
│   ├── adr/                          # Architecture Decision Records (MADR-lite)
│   │   ├── README.md                 # Índice y guía para nuevos ADRs
│   │   ├── template.md
│   │   ├── 0001-marco-gobernanza-repositorios.md
│   │   ├── 0002-politicas-repositorios-desarrollo.md
│   │   ├── 0003-politicas-repositorios-produccion.md
│   │   ├── 0004-creacion-automatizada-repositorios.md
│   │   └── 0005-creacion-repos-scaffold-minimo.md
│   ├── templates/                    # Plantillas de configuración por stack (sync source)
│   │   ├── dependabot-dotnet.yml
│   │   ├── dependabot-node-bun.yml
│   │   ├── dependabot-docker.yml
│   │   ├── dependabot-terraform.yml
│   │   ├── dependabot-github-actions.yml
│   │   └── security-checks.yml
│   └── repos-manifest.yml            # Inventario de repos consumidores (sync target)
├── CLAUDE.md                         # Guía para agentes (etiquetado de release al crear PRs)
└── README.md                         # Este archivo
```

## Para gobernanza de repos, empezar por

- [`docs/adr/0001-marco-gobernanza-repositorios.md`](docs/adr/0001-marco-gobernanza-repositorios.md) — marco operativo, catálogo neutral de prácticas, principios y mapa de decisiones.
- [`docs/adr/0002-politicas-repositorios-desarrollo.md`](docs/adr/0002-politicas-repositorios-desarrollo.md) — decisiones aplicables hoy + guía de implementación con comandos `gh`. Sync workflow documentado en §E.3 y §D.7.
- [`docs/adr/0003-politicas-repositorios-produccion.md`](docs/adr/0003-politicas-repositorios-produccion.md) — políticas propuestas para cuando exista ambiente de producción.

## Para usar los reusables, ver

- [`.github/workflows/README.md`](.github/workflows/README.md) — catálogo de los 14 reusables, sus inputs, sus checks expuestos, patrón de consumo y **versionado** (etiquetas `release:move` / `release:major`).

## Para entender el sync

- [`docs/repos-manifest.yml`](docs/repos-manifest.yml) — inventario de repos consumidores con su stack y overrides. Editar para hacer onboarding/offboarding.
- [`.github/workflows/sync-governance.yml`](.github/workflows/sync-governance.yml) — propaga cambios. Triggers: push a `main` con cambios en templates/manifest/reusables, o `workflow_dispatch` (con `dry_run`).
- [`.github/workflows/drift-check-governance.yml`](.github/workflows/drift-check-governance.yml) — cron semanal. Reporta drift en una issue actualizable de este repo.

## Crear un repo nuevo

Para crear un repo ya gobernado, usar el workflow **`create-repo.yml`**
(`workflow_dispatch`). Solo pide el **nombre del repo** (y un `dry_run`); el flujo:

1. Crea el repo (privado) en la org.
2. Aplica los settings que el ruleset org no cubre: squash-only, auto-merge y auto-delete
   de la rama al mergear.
3. Scaffoldea el **baseline de seguridad** (`security-checks.yml`) y hace el **commit
   inicial de `main`** (la App es bypass actor del ruleset org; de ahí en adelante todo
   entra por PR). El `dependabot.yml` lo coloca el sync. El flujo de creación **no** crea CI/CD de
   negocio ni de devops (build/deploy/publish/terraform): eso lo añaden las skills de
   onboarding o el equipo, post-infra (ver ADR 0005).
4. Registra la entrada en `docs/repos-manifest.yml` **vía PR en este repo** (con
   **auto-merge** habilitado: se mergea solo en cuanto pasan los checks) — a partir de ahí
   el sync y el drift-check ya gobiernan el repo nuevo.
5. Crea un repo-level ruleset con los **required status checks** del baseline de seguridad.

El input `dry_run` (por defecto `true`) valida y muestra el plan sin crear nada. Decisiones
de diseño en [`docs/adr/0004-creacion-automatizada-repositorios.md`](docs/adr/0004-creacion-automatizada-repositorios.md)
y [`docs/adr/0005-creacion-repos-scaffold-minimo.md`](docs/adr/0005-creacion-repos-scaffold-minimo.md).

### Precondiciones (configuración fuera del repo)

El flujo corre con una **GitHub App dedicada de creación** (`cosmos-repo-creator`), separada
de la del sync para acotar el blast radius (ADR 0004). Esa App debe configurarse con
permisos granulares mínimos:

| Permiso | Nivel | Para qué |
|---|---|---|
| Repository → Administration | Read & write | crear repos, settings de merge y el repo-level ruleset |
| Repository → Contents | Read & write | commit inicial de `main` + rama del PR de manifest |
| Repository → Workflows | Read & write | pushear archivos bajo `.github/workflows/*` |
| Repository → Pull requests | Read & write | abrir el PR de manifest en este repo |
| Repository → Metadata | Read-only | obligatorio (auto-seleccionado) |

Además:

- **Instalar la App en la org con acceso a "All repositories"** (para administrar repos recién creados).
- Añadir la App a la **bypass list del ruleset org `~DEFAULT_BRANCH`** (ADR 0002 §B.1), para el commit inicial de `main`.
- Guardar `REPO_CREATOR_APP_CLIENT_ID` y `REPO_CREATOR_APP_PRIVATE_KEY` como secrets accesibles a este repo (`create-repo.yml` los consume).

No requiere permisos de organización ni de Issues. Es un set estrictamente acotado a la
creación, distinto al de la App del sync.

## Operación: onboarding (backfill) de un repo legacy al manifest

Para repos que ya existen pero no nacieron por este flujo, `scan-repo.sh` propone el
bloque YAML listo para pegar en `docs/repos-manifest.yml` haciendo un clone shallow del repo
e infiriendo stack + overrides.

```bash
$ bash .github/scripts/scan-repo.sh Cosmos.NuevoRepo
  - name: Cosmos.NuevoRepo
    stack: dotnet  # inferido
    consumes: [reusables, dependabot]
    overrides:
      docker_directories:
        - /Cosmos.NuevoRepo.API
```

Heurísticas: `*.csproj`/`*.sln`→`dotnet`, `package.json`→`node-bun`, `*.tf`→`terraform`, sino `github-actions`. Detecta `Dockerfile`s para `docker_directories` y `/infra` como `terraform_directory` cuando aplica. La salida es una sugerencia — revisar antes de pegar.

## Repositorios relacionados

- [`Cosmos-SincoERP/Cosmos.AgentSkills`](https://github.com/Cosmos-SincoERP/Cosmos.AgentSkills) — ex-`Cosmos.PlatformWorkflows`; origen histórico de los reusables. Renombrado tras la migración (mayo 2026). Ahora aloja solo las skills de Claude (`onboard-dotnet-repo`, `provision-bc-infra`) y el catálogo de bounded contexts.
