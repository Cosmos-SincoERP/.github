# `.github` — Cosmos-SincoERP

Repositorio especial de la organización **Cosmos-SincoERP**. Cumple dos funciones:

1. **Defaults org-wide (community health files)**. Los archivos en este repo bajo rutas como `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/*`, `SECURITY.md`, `CODEOWNERS`, `.github/dependabot.yml` actúan como **defaults para cualquier repo de la organización que no tenga el suyo propio**.

2. **Documentación de gobernanza operacional**. ADRs sobre políticas de repositorios, gobierno de la organización y prácticas de plataforma. Ver `docs/adr/`.

## Estructura

```
.
├── docs/
│   ├── adr/                  # Architecture Decision Records (MADR-lite)
│   │   ├── README.md         # Índice y guía para nuevos ADRs
│   │   ├── template.md       # Plantilla MADR-lite a copiar
│   │   ├── 0001-marco-gobernanza-repositorios.md
│   │   ├── 0002-politicas-repositorios-desarrollo.md
│   │   └── 0003-politicas-repositorios-produccion.md
│   └── templates/            # Plantillas de configuración por stack
│       ├── dependabot-dotnet.yml
│       ├── dependabot-node-bun.yml
│       ├── dependabot-docker.yml
│       ├── dependabot-terraform.yml
│       └── dependabot-github-actions.yml
└── README.md                 # Este archivo
```

## Para gobernanza de repos, empezar por

- [`docs/adr/0001-marco-gobernanza-repositorios.md`](docs/adr/0001-marco-gobernanza-repositorios.md) — marco operativo, catálogo neutral de prácticas, principios y mapa de decisiones.
- [`docs/adr/0002-politicas-repositorios-desarrollo.md`](docs/adr/0002-politicas-repositorios-desarrollo.md) — decisiones aplicables hoy + guía de implementación con comandos `gh`.
- [`docs/adr/0003-politicas-repositorios-produccion.md`](docs/adr/0003-politicas-repositorios-produccion.md) — políticas propuestas para cuando exista ambiente de producción.

## Repositorios relacionados

- [`Cosmos-SincoERP/Cosmos.PlatformWorkflows`](https://github.com/Cosmos-SincoERP/Cosmos.PlatformWorkflows) — workflows reutilizables consumidos por los repos de la organización.
