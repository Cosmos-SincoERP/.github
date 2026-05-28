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
│   │   ├── _reusable-*.yml          # 10 reusables migrados desde Cosmos.PlatformWorkflows
│   │   ├── create-repo.yml          # Golden path: crea repos gobernados por arquetipo
│   │   ├── sync-governance.yml      # Propaga cambios a repos consumidores
│   │   ├── drift-check-governance.yml  # Reporta drift semanalmente
│   │   └── README.md                # Doc de los reusables (catálogo + uso)
│   └── scripts/
│       ├── create-repo.sh           # Lógica del golden path de creación
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
│   │   └── 0004-creacion-automatizada-repositorios.md
│   ├── archetypes/                   # Plantillas de creación por arquetipo (golden path)
│   │   ├── README.md                 # Esquema de archetype.yml + sustitución
│   │   └── <arquetipo>/              # archetype.yml + files/ (scaffold con placeholders)
│   ├── templates/                    # Plantillas de configuración por stack (sync source)
│   │   ├── dependabot-dotnet.yml
│   │   ├── dependabot-node-bun.yml
│   │   ├── dependabot-docker.yml
│   │   ├── dependabot-terraform.yml
│   │   ├── dependabot-github-actions.yml
│   │   └── security-checks.yml
│   └── repos-manifest.yml            # Inventario de repos consumidores (sync target)
└── README.md                         # Este archivo
```

## Para gobernanza de repos, empezar por

- [`docs/adr/0001-marco-gobernanza-repositorios.md`](docs/adr/0001-marco-gobernanza-repositorios.md) — marco operativo, catálogo neutral de prácticas, principios y mapa de decisiones.
- [`docs/adr/0002-politicas-repositorios-desarrollo.md`](docs/adr/0002-politicas-repositorios-desarrollo.md) — decisiones aplicables hoy + guía de implementación con comandos `gh`. Sync workflow documentado en §E.3 y §D.7.
- [`docs/adr/0003-politicas-repositorios-produccion.md`](docs/adr/0003-politicas-repositorios-produccion.md) — políticas propuestas para cuando exista ambiente de producción.

## Para usar los reusables, ver

- [`.github/workflows/README.md`](.github/workflows/README.md) — catálogo de los 10 reusables, sus inputs, sus checks expuestos, y patrón de consumo.

## Para entender el sync

- [`docs/repos-manifest.yml`](docs/repos-manifest.yml) — inventario de repos consumidores con su stack y overrides. Editar para hacer onboarding/offboarding.
- [`.github/workflows/sync-governance.yml`](.github/workflows/sync-governance.yml) — propaga cambios. Triggers: push a `main` con cambios en templates/manifest/reusables, o `workflow_dispatch` (con `dry_run`).
- [`.github/workflows/drift-check-governance.yml`](.github/workflows/drift-check-governance.yml) — cron semanal. Reporta drift en una issue actualizable de este repo.

## Golden path: crear un repo nuevo

Para crear un repo ya gobernado, usar el workflow **`create-repo.yml`**
(`workflow_dispatch`). Dado un **arquetipo** (`dotnet-service`, `dotnet-library-nuget`,
`frontend`, `gateway`, `infra`, `placeholder`), el flujo:

1. Crea el repo (privado por defecto) en la org.
2. Aplica los settings que el ruleset org no cubre: squash-only, auto-merge y auto-delete
   de la rama al mergear.
3. Scaffoldea el CI/CD del arquetipo (wrappers que invocan los reusables) + `dependabot.yml`
   + `security-checks.yml`, y hace el **commit inicial de `main`** (la App es bypass actor
   del ruleset org; de ahí en adelante todo entra por PR).
4. Registra la entrada en `docs/repos-manifest.yml` **vía PR en este repo** — al mergearlo,
   el sync y el drift-check ya gobiernan el repo nuevo.
5. Crea un repo-level ruleset con los **required status checks** del arquetipo.

El input `dry_run` (por defecto `true`) valida y muestra el plan sin crear nada. Las
plantillas y el esquema de arquetipos viven en [`docs/archetypes/`](docs/archetypes/).
Decisión de diseño en [`docs/adr/0004-creacion-automatizada-repositorios.md`](docs/adr/0004-creacion-automatizada-repositorios.md).

### Precondiciones (configuración fuera del repo)

El flujo corre con un token de GitHub App. Respecto a los permisos que ya necesita el sync
(Contents + Pull requests), el golden path requiere **adicionalmente** que la App tenga:

- **Administration (organización)** — para crear repos.
- **Administration (repositorio)** — para aplicar settings de merge y crear el repo-level ruleset.
- **Workflows** — sin esto, el push inicial que toca `.github/workflows/*` es rechazado.
- Estar en la **bypass list del ruleset org `~DEFAULT_BRANCH`** (ADR 0002 §B.1), para el
  commit inicial de `main` del repo nuevo.

> Por blast radius, se puede usar una App separada solo-creación en vez de ampliar la del
> sync; en ese caso, ajustar los secrets referenciados en `create-repo.yml`. Ver ADR 0004.

## Operación: onboarding (backfill) de un repo legacy al manifest

Para repos que ya existen pero no nacieron por el golden path, `scan-repo.sh` propone el
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
