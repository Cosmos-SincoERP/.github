---
status: proposed
date: 2026-05-30
deciders: [augusto-romero-arango]
consulted: []
informed: []
---

# 0005 — Golden path: scaffold mínimo (baseline + seguridad); CI/CD deferido al onboarding

## Contexto y problema

[[0004]] adoptó el golden path de creación (`create-repo.yml` + arquetipos) que, además
del baseline de gobernanza, scaffoldea el **CI/CD completo** del tipo de repo: para
`dotnet-service` y `gateway` eso son los wrappers de build/deploy a Swarm, el
`imagenes-docker.yml` y el `deploy/stack.dev.yml`.

Ese CI/CD se solapa con las skills de onboarding del repo `Cosmos.AgentSkills`
(`onboard-dotnet-repo`), que generan exactamente los mismos artefactos pero **dirigidos
por descubrimiento**: escanean los Dockerfiles y proyectos reales, derivan la matriz de
imágenes, excluyen tests que requieren docker, parchean `Program.cs`, y — sobre todo —
rellenan los valores reales del bounded context (ACR, Key Vault, **runner group**, redes)
desde `bounded-contexts.yml`.

El scaffold del golden path no puede hacer ese descubrimiento (el repo nace vacío): emite
un esqueleto con `TODO`s. Peor, omite inputs que los reusables declaran `required` — en
particular `runner_group` (que `_reusable-docker-build-push` y `_reusable-deploy-swarm`
exigen) —, de modo que el `main-deploy-dev.yml` scaffoldeado fallaría en validación en el
primer push a `main`. Mantener dos generadores del mismo CI/CD (uno ciego, uno con
contexto) duplica superficie y deja al de creación permanentemente incompleto.

Por otro lado, el `dependabot.yml` ya lo gestiona el sync/drift de gobernanza
(`sync-governance.sh` / `drift-check-governance.sh`, keyed en `consumes`/`stack` del
manifest); que `create-repo.sh` además lo renderice al crear es redundante.

Pregunta de decisión: ¿qué parte del CI/CD debe producir el golden path al crear un repo,
y qué parte se defiere a las skills de onboarding?

## Drivers de decisión

Heredados de [[0001]]:

1. Consistencia de gobierno — un repo nace conforme al baseline y bajo gobernanza.
2. Fricción mínima — sin pasos manuales ni artefactos rotos que el equipo deba arreglar.
3. Una sola fuente por responsabilidad — evitar dos generadores del mismo artefacto.
4. Adaptación al flujo IA — el descubrimiento del CI/CD encaja mejor en una skill
   interactiva con contexto del BC que en un scaffold headless.

## Opciones consideradas

- **A. Statu quo**: el golden path scaffoldea el CI/CD completo (con `TODO`s) y la skill
  de onboarding lo regenera/sobrescribe después. Doble fuente; el scaffold queda roto
  (`runner_group` ausente) hasta que alguien lo arregle a mano o corra la skill.
- **B. Enriquecer el scaffold**: portar el descubrimiento (scan de Dockerfiles,
  Testcontainers, `Program.cs`) al `create-repo.sh`. Inviable: el repo nace vacío, no hay
  nada que descubrir en el momento de la creación.
- **C. Minimizar el golden path**: el scaffold deja solo baseline + seguridad (+ skeleton
  de app donde aplique); el CI/CD de Swarm lo agrega la skill de onboarding cuando ya
  existe la infra del BC. El `dependabot.yml` queda a cargo del sync/drift (como ya está).

## Decisión

Se adopta la **opción C**, refinando [[0004]] §1:

1. **El scaffold de los arquetipos de Swarm (`dotnet-service`, `gateway`) se reduce a
   baseline + seguridad** (+ skeleton de app: el `gateway` conserva `Dockerfile` y
   `nginx.conf`). Se quitan del scaffold los 4 wrappers de CI/CD, el `imagenes-docker.yml`
   y el `deploy/stack.dev.yml`.
2. **El CI/CD de Swarm lo agregan las skills de onboarding** post-infra: `dotnet-service`
   → `/onboard-dotnet-repo`; `gateway` → `/onboard-gateway-repo` (ambas en
   `Cosmos.AgentSkills`). Esas skills rellenan los valores reales del BC, incluido
   `runner_group`.
3. **`required_checks` de `dotnet-service` deja de incluir `tests / tests`** (ese check lo
   trae el CI/CD que ahora agrega la skill). Quedan solo los de seguridad
   (`dependency-review / trivy`, `secret-scan / trufflehog`). `gateway` no cambia (ya era
   solo seguridad).
4. **`create-repo.sh` deja de renderizar `dependabot.yml`** al crear. El sync/drift lo
   coloca y mantiene según el manifest; el `consumes: [reusables, dependabot]` del
   arquetipo se conserva intacto para que esa gestión siga ocurriendo.

Los arquetipos sin despliegue a Swarm (`dotnet-library-nuget`, `frontend`, `infra`,
`placeholder`) **no cambian** su scaffold de CI/CD en esta decisión.

## Consecuencias

- ✅ Un solo generador del CI/CD de Swarm (las skills, con contexto del BC); el golden
  path deja de emitir artefactos incompletos (se elimina el `runner_group` faltante).
- ✅ El repo sigue naciendo conforme: baseline + seguridad + (para gateway) skeleton, y
  bajo gobernanza desde el registro en el manifest.
- ✅ El `dependabot.yml` tiene una sola fuente (sync/drift), sin render redundante al crear.
- ⚠️ **Ventana sin CI/CD**: entre crear el repo y correr la skill de onboarding, el repo no
  tiene workflows de build/deploy. Es intencional — el CI/CD depende de que exista la infra
  del BC. Mitigación: el README scaffoldeado lo explica y apunta a la skill correspondiente.
- ⚠️ **Dependencia de secuencia**: el onboarding debe correr después de `provision-bc-infra`
  (que registra el BC en `bounded-contexts.yml`). Documentado en ambas skills.
- ⚠️ **Cobertura de arquetipos**: la frontera nueva solo cubre los tipos que una skill puede
  asumir (`dotnet-service`, `gateway`). `dotnet-library-nuget`/`frontend` conservan su CI/CD
  en el golden path; si en el futuro se les quiere dar el mismo trato, requieren su propia
  skill o decisión.

## Referencias

- [[0004]] — Golden path de creación de repositorios (este ADR refina su §1).
- [[0002]] — Políticas de repositorios: desarrollo (§B.1, §D.1, §E.3 sync/drift).
- `Cosmos-SincoERP/Cosmos.AgentSkills` — skills `onboard-dotnet-repo`, `onboard-gateway-repo`.
