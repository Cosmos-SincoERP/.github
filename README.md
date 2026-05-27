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
│   │   ├── sync-governance.yml      # Propaga cambios a repos consumidores
│   │   ├── drift-check-governance.yml  # Reporta drift semanalmente
│   │   └── README.md                # Doc de los reusables (catálogo + uso)
│   └── scripts/
│       ├── sync-governance.sh       # Lógica del sync
│       └── drift-check-governance.sh
├── docs/
│   ├── adr/                          # Architecture Decision Records (MADR-lite)
│   │   ├── README.md                 # Índice y guía para nuevos ADRs
│   │   ├── template.md
│   │   ├── 0001-marco-gobernanza-repositorios.md
│   │   ├── 0002-politicas-repositorios-desarrollo.md
│   │   └── 0003-politicas-repositorios-produccion.md
│   ├── templates/                    # Plantillas de configuración por stack (sync source)
│   │   ├── dependabot-dotnet.yml
│   │   ├── dependabot-node-bun.yml
│   │   ├── dependabot-docker.yml
│   │   ├── dependabot-terraform.yml
│   │   └── dependabot-github-actions.yml
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

## Repositorios relacionados

- [`Cosmos-SincoERP/Cosmos.AgentSkills`](https://github.com/Cosmos-SincoERP/Cosmos.AgentSkills) — ex-`Cosmos.PlatformWorkflows`; origen histórico de los reusables. Renombrado tras la migración (mayo 2026). Ahora aloja solo las skills de Claude (`onboard-dotnet-repo`, `provision-bc-infra`) y el catálogo de bounded contexts.
