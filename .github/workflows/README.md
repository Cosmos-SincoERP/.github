# Workflows reusables — Plataforma CI/CD

> **Migrado desde `Cosmos-SincoERP/Cosmos.PlatformWorkflows`** (ver ADR 0002 §D.7), repo origen ya renombrado a `Cosmos-SincoERP/Cosmos.AgentSkills`. Los reusables viven ahora en este repo `.github` org-wide; el repo de skills conserva solo `onboard-dotnet-repo` y `provision-bc-infra` con sus templates.

Este directorio contiene los **workflows reutilizables (`_reusable-*.yml`)** que componen la maquinaria compartida de CI/CD del ecosistema Cosmos. Todos los repos del plane (aplicativos, infraestructura, fronts) los consumen para tests, build y push de imágenes Docker, deploy a Swarm/Storage, y publicación NuGet.

Patrón de consumo desde cada repo consumidor:

```yaml
jobs:
  tests:
    uses: Cosmos-SincoERP/.github/.github/workflows/_reusable-tests-dotnet.yml@v1
    with:
      # ver inputs específicos en la sección "Reusables disponibles" más abajo
```

El tag `@v1` es mutable: avanza con cada release no-breaking. Breaking changes publican un nuevo major (`@v2`, `@v3`) y se documentan en [`CHANGELOG.md`](../../CHANGELOG.md).

---

## Checks expuestos (para Rulesets de repos consumidores)

Cada reusable expone un **nombre de check** estable —declarado en su clave `name:` de nivel raíz— que es el identificador exacto que GitHub muestra en la UI de PRs y, sobre todo, el string que los repos consumidores deben usar al marcar checks como **required** en sus Rulesets de branch protection (ADR [`0002`](../../docs/adr/0002-politicas-repositorios-desarrollo.md), decisiones **B.4** y **D.1**).

Mantener estos nombres estables es contrato público: cambiarlos rompe los Rulesets aguas abajo y debe tratarse como breaking change con bump de major (`@v1` → `@v2`) más anuncio en [`CHANGELOG.md`](../../CHANGELOG.md).

| Workflow file | Check name | Propósito | Inputs principales |
| --- | --- | --- | --- |
| `_reusable-bump-and-tag.yml` | `Bump SemVer + tag (reusable)` | Calcula siguiente SemVer consultando nuget.org, crea y empuja tag git, opcionalmente abre GitHub Release. | `package_id`, `tag_prefix`, `bump_type`, `initial_version`, `create_github_release` |
| `_reusable-cleanup-acr-pr.yml` | `Cleanup ACR — tags de PR (reusable)` | Borra tags `pr-*` huérfanos en ACR (modo dirigido por PR cerrado, o barrido por edad). | `acr_name`, `repository_prefix`, `repositories_json`, `pr_number`, `keep_sha7` |
| `_reusable-dependency-review.yml` | `Dependency Review` | Bloquea PRs que introducen dependencias vulnerables o con licencias prohibidas (ADR 0002 E.4). | `fail-on-severity`, `deny-licenses` |
| `_reusable-deploy-front.yml` | `Deploy Front estático (reusable)` | Despliega SPA Bun a Storage Account `$web` con activación atómica y env.js generado desde Key Vault. | `app_name`, `web_endpoint`, `storage_account`, `key_vault_name`, `environment`, `github_packages` |
| `_reusable-deploy-swarm.yml` | `Deploy a Docker Swarm (reusable)` | Despliega un stack Compose a un Docker Swarm self-hosted inyectando tags por servicio. | `stack_file`, `stack_name`, `image_tag`, `image_tags_json`, `acr_name`, `stack_environment` |
| `_reusable-docker-build-push.yml` | `Build & Push Docker (reusable)` | Build multi-imagen contra ACR con alias mutables derivados del contexto (PR / main / manual). | `images_json`, `acr_name`, `repository_prefix`, `ref_context_override`, `mutable_alias_override` |
| `_reusable-nuget-publish.yml` | `NuGet publish (reusable)` | Empaqueta un `.csproj` y publica al feed NuGet configurado (default nuget.org). | `project_path`, `package_version`, `dotnet_version`, `nuget_source` + secret `NUGET_API_KEY` |
| `_reusable-nuget-publish-batch.yml` | `NuGet publish batch (reusable)` | Versiona y publica **varios** paquetes NuGet en una sola corrida: SemVer + tag por paquete (secuencial) y `pack`/`push` en paralelo (matriz). Mismo `bump_type` para todos. | `packages_json`, `bump_type`, `dotnet_version`, `nuget_source`, `create_github_release` + secret `NUGET_API_KEY` |
| `_reusable-npm-publish.yml` | `Publicar a <registro> (reusable)` | Publica una librería npm (no versiona): `build` + `changeset publish` (idempotente). Soporta npm público (secret `NPM_TOKEN`) y GitHub Packages (con el `GITHUB_TOKEN` del workflow). | `working_directory`, `bun_version`, `npm_registry`, `publish_command` + secret opcional `NPM_TOKEN` |
| `_reusable-secret-scan.yml` | `Secret Scan (gitleaks)` | Mitigación open-source de secret scanning (gitleaks) para repos privados sin GHAS (ADR 0002 E.6). | `config-path` |
| `_reusable-tests-dotnet.yml` | `Tests .NET (reusable)` | Restore + build + test de soluciones .NET, con exclusión de proyectos opcional. | `solution_path`, `working_directory`, `dotnet_version`, `configuration`, `excluded_projects` |
| `_reusable-ci-front.yml` | `CI Front (reusable)` | Lint + test + build de fronts SPA (Bun), cada step togglable. | `working_directory`, `bun_version`, `run_lint`, `run_test`, `run_build`, `github_packages` |

> Ejemplo de Ruleset (en el repo consumidor): para hacer required el check de un PR que invoca `_reusable-dependency-review.yml`, el repo debe listar exactamente el string **`Dependency Review`** en `required_status_checks`. El mismo principio aplica para los otros nueve.

---

## 1. Visión general

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Cada repo de aplicación define en .github/workflows/ un workflow corto │
│  por evento (PR, push a main, cierre de PR, schedule). Esos workflows   │
│  invocan los reusables de este repo:                                     │
│                                                                          │
│   PR open/sync   ──▶ _reusable-tests-* (hosted)                          │
│                  ──▶ _reusable-docker-build-push (self-hosted)           │
│                  ──▶ _reusable-cleanup-acr-pr   (self-hosted) [intra-PR] │
│                                                                          │
│   push a main    ──▶ _reusable-tests-* (hosted)                          │
│                  ──▶ _reusable-docker-build-push (self-hosted)           │
│                  ──▶ _reusable-deploy-swarm (self-hosted)                │
│                                                                          │
│   push a main    ──▶ _reusable-deploy-front (self-hosted, MI)           │
│   (frontends)                                                            │
│                                                                          │
│   PR closed      ──▶ _reusable-cleanup-acr-pr (self-hosted) [pr_number]  │
│                                                                          │
│   schedule       ──▶ _reusable-cleanup-acr-pr (self-hosted) [barrido]    │
└──────────────────────────────────────────────────────────────────────────┘
```

### División de runners

| Tipo de trabajo | Runner | Motivo |
|---|---|---|
| Lint, tests unitarios, build de código (`dotnet`, `bun`) | `ubuntu-latest` (hosted) | Gratis, paralelo entre PRs concurrentes, sin tocar la VM productiva. |
| `docker build`, `docker push` al ACR | `[self-hosted, azure, swarm-deploy]` | Usa la **Managed Identity** de la VM (cero secretos en GitHub) y aprovecha el cache de capas Docker local. |
| `docker stack deploy` al Swarm | `[self-hosted, azure, swarm-deploy]` | El Swarm corre en la misma VM; el deploy es un comando local. |
| Cleanup del ACR | `[self-hosted, azure, swarm-deploy]` | Reaprovecha el `az login --identity` del entorno. |
| Build + deploy de SPAs estáticos a Storage | `[self-hosted, azure, swarm-deploy]` | Reaprovecha `az login --identity` y los roles RBAC ya asignados a la MI de la VM (KV + Storage). Sin GH Actions secrets de Azure. |

---

## 2. Catálogo de reusables

### `_reusable-tests-dotnet.yml`

Build + test de una solución .NET en runner hosted.

| Input | Tipo | Default | Descripción |
|---|---|---|---|
| `solution_path` | string | (descubre `*.sln`) | Ruta a `.sln` o `.csproj`. |
| `working_directory` | string | `.` | Directorio donde se ejecuta `dotnet`. |
| `dotnet_version` | string | `10.0.x` | Versión del SDK. |
| `configuration` | string | `Release` | `Debug` o `Release`. |

### `_reusable-ci-front.yml`

Lint + test + build del front SPA con Bun en runner hosted (el CI completo del front).

| Input | Tipo | Default | Descripción |
|---|---|---|---|
| `working_directory` | string | `.` | Donde está `package.json`. |
| `bun_version` | string | `latest` | Versión de Bun. |
| `run_lint`, `run_test`, `run_build` | boolean | `true` | Activar/desactivar etapas. |
| `github_packages` | boolean | `false` | Si el front consume paquetes del org desde GitHub Packages (p. ej. `@cosmos-sincoerp/asistente`). En `true`, escribe un `.npmrc` autenticado con el `GITHUB_TOKEN` antes de `bun install`. En `false` el comportamiento es idéntico al actual. |

> **Consumir `@cosmos-sincoerp/*` desde GitHub Packages:** poné `github_packages: true` y agregá un `.npmrc` al repo del front (mapea el scope a `npm.pkg.github.com`). El reusable declara `packages: read`; el caller no necesita configurar secrets (usa el `GITHUB_TOKEN`). Ver el skill `publish-npm-library` para el lado productor.

### `_reusable-docker-build-push.yml`

Construye una matriz de imágenes Docker en self-hosted y las publica al ACR vía Managed Identity. **Es la única fuente de verdad de los tags publicados**: expone outputs y, para eventos `pull_request`, sube un artifact `pr-{N}-images-manifest` que el deploy a main consume sin recalcular SHAs.

| Input | Tipo | Default | Descripción |
|---|---|---|---|
| `images_json` | string (JSON) | **requerido** | Array `[{name, dockerfile, context}]`. |
| `acr_name` | string | `croxpdeveus2001` | Nombre del ACR. |
| `repository_prefix` | string | `oxp` | Prefijo del repo en ACR. |
| `ref_context_override` | string | (auto) | Forzar contexto del tag inmutable. |
| `mutable_alias_override` | string | (auto) | Forzar alias mutable. `none` deshabilita. |
| `buildx_builder_name` | string | `oxp-builder` | Nombre del builder buildx reutilizable. Cambiar en contextos multi-dominio sobre la misma VM. |

| Output | Descripción |
|---|---|
| `ref_context` | Contexto del ref (`pr-{n}`, `main`, `manual`). |
| `sha7` | Primeros 7 chars del SHA del commit cuyo build se pushó. Para `pull_request` es la HEAD del PR (no la merge-ref sintética que GitHub usa por default en `GITHUB_SHA`); para `push`/`workflow_dispatch`/`schedule` es el commit del ref. |
| `image_tags_json` | Mapa `{ "<name>": "<ref_context>-<sha7>" }` con el tag inmutable publicado por imagen. Los wrappers deben consumirlo en lugar de derivar tags por su cuenta. |

**Tags publicados** (ver §3):
- Inmutable: `{acr}.azurecr.io/{prefix}/{name}:{ref_context}-{sha7}`
- Alias (si aplica): `{acr}.azurecr.io/{prefix}/{name}:{mutable_alias}`

**Artifact (sólo `pull_request`)**: `pr-{N}-images-manifest` con `manifest.json` (`pr_number`, `head_sha`, `head_sha7`, `ref_context`, `image_tags_json`, `images_json`). Lo consume `main-deploy-dev.yml` al detectar el merge para reusar exactamente esos tags al promover a `main-{merge_sha7}`.

### `_reusable-deploy-swarm.yml`

Despliega un stack a Docker Swarm.

| Input | Tipo | Default | Descripción |
|---|---|---|---|
| `stack_file` | string | **requerido** | Ruta al compose. |
| `stack_name` | string | **requerido** | Nombre del stack en Swarm. |
| `image_tag` | string | `""` | Tag global para `${IMAGE_TAG}` (modo legado). Ignorado si se da `image_tags_json`. |
| `image_tags_json` | string (JSON) | `{}` | Mapa `{servicio: tag}`. Cada servicio expone `IMAGE_TAG_<UPPER_SNAKE>`. Servicios omitidos toman el tag actual desplegado. Con `{}` y `image_tag=""` el reusable hace resync del stack file con todos los tags actuales de Swarm (útil para refrescar replicas/healthchecks sin cambios de imagen). |
| `acr_name` | string | `croxpdeveus2001` | Para `az acr login`. |
| `repository_prefix` | string | `oxp` | Inyectado como `${REPOSITORY_PREFIX}`. |
| `env_vars_json` | string (JSON) | `{}` | Variables extra para el compose. |
| `stack_environment` | string | `dev` | Etiqueta para el step summary. |
| `key_vault_name` | string | `kv-oxp-dev-eus2-001` | KV desde donde leer secretos. |
| `secret_names` | string | `""` | Lista separada por espacios de nombres KV a materializar. Vacío deshabilita. |
| `swarm_secret_prefix` | string | `oxp` | Prefijo del nombre del Swarm secret (`<prefix>_<snake>_v<sha8>`). Usado también para identificar secrets propios al hacer GC. |

### `_reusable-deploy-front.yml`

Build + test + deploy de un SPA al Storage Account static website. Sigue el patrón **build once, deploy anywhere**: bundle inmutable bajo `$web/<app_name>/releases/<sha>/`, `env.js` runtime en `$web/<app_name>/env.js` con `Cache-Control: no-cache`, swap atómico del `<app_name>/index.html`. El prefijo `<app_name>/` permite hospedar todos los fronts del plane en un único Storage Account compartido (`stfrontappldeveus2001`). Corre en runner self-hosted (`[self-hosted, azure, swarm-deploy]`) y autentica con `az login --identity` reutilizando la Managed Identity de la VM — el mismo patrón que `_reusable-deploy-swarm.yml`. **Sin OIDC, sin GH Actions secrets de Azure.**

| Input | Tipo | Default | Descripción |
|---|---|---|---|
| `app_name` | string | **requerido** | Identificador corto (2-8 chars). Se usa para derivar el nombre de los secrets en KV (`front-<app>-...`). |
| `environment` | string | **requerido** | Etiqueta lógica del ambiente (dev/qa/prod). Solo informativa. |
| `storage_account_name` | string | **requerido** | SA compartido de fronts del plane: `stfrontappldeveus2001` (RG `rg-appl-dev-eus2-001`, infra de ApplicationPlane). |
| `web_endpoint` | string | **requerido** | URL del web endpoint con el prefijo del front (`https://stfrontappldeveus2001.z20.web.core.windows.net/<app_name>/`). Usado para smoke test. |
| `key_vault_name` | string | **requerido** | KV con los secretos de configuración del `env.js` (ej. `kv-oxp-dev-eus2-001`). |
| `bun_version` | string | `latest` | Versión de Bun a instalar. |
| `working_directory` | string | `.` | Directorio donde está `package.json` (y, debajo de él, `.deploy/env.js.tmpl`). |
| `github_packages` | boolean | `false` | Si el front consume paquetes del org desde GitHub Packages. En `true`, el job `build` escribe un `.npmrc` autenticado con el `GITHUB_TOKEN` antes de `bun install` (el reusable declara `packages: read`). En `false`, sin cambios. |

**Plantilla del `env.js`: propiedad de cada front**, en `<working_directory>/.deploy/env.js.tmpl` del repo del front. El reusable es **agnóstico al shape** del template: extrae los placeholders `${VAR_NAME}` con grep, deriva el nombre del secret en KV por convención y resuelve con `envsubst`.

| Mecanismo | Comportamiento |
|---|---|
| **Convención de naming** | `${VAR_NAME}` → `front-<app_name>-var-name` (lowercase, `_` → `-`). Ej: `${API_BASE_URL}` con `app_name: oxp` → `front-oxp-api-base-url`. |
| **Escape hatch** | Archivo opcional `<working_directory>/.deploy/env.map` con `VAR=secret-name` por línea (soporta `#` comentarios). Permite mapear una var a un nombre de secret distinto del que daría la convención (ej. para reusar un secret compartido entre varios fronts). |
| **Validación de sintaxis** | Si `node` está disponible en el runner, corre `node --check env.js` después del envsubst. Atrapa típos del template (ej. un valor no numérico que rompe un literal sin comillas). |
| **Failure modes** | Sin `.deploy/env.js.tmpl` → falla con mensaje claro. Secret no existe en KV → falla en el `az keyvault secret show`. Sintaxis inválida → falla en `node --check`. |

**Roles RBAC requeridos sobre la MI de la VM** (`module.vm.identity_principal_id`):

| Rol | Recurso | Estado |
|---|---|---|
| `Key Vault Secrets User` | KV de environment (`kv-oxp-dev-eus2-001`) | ✅ Asignado por `module.key_vault.vm_secrets_user` |
| `Storage Blob Data Contributor` | SA compartido de fronts del plane (`stfrontappldeveus2001`, RG `rg-appl-dev-eus2-001`) | ⚠️ **Pendiente** — hoy ese rol lo tiene el SP de tfops, no la MI de la VM del BC. Asignarlo manualmente vía `az role assignment create` antes del primer deploy de cada BC (ver §5b paso 2). |

### `_reusable-nuget-publish.yml`

Empaqueta un `.csproj` y publica el `.nupkg` resultante a un feed NuGet (por default `nuget.org`). Corre en runner hosted (`ubuntu-latest`) porque no necesita Managed Identity ni acceso al ACR — la auth al feed es por API key. Usa `setup-dotnet@v4` y `--skip-duplicate` para que un re-disparo de un tag ya publicado no rompa el job.

| Input | Tipo | Default | Descripción |
|---|---|---|---|
| `project_path` | string | **requerido** | Ruta al `.csproj` a empaquetar (relativa al checkout). |
| `package_version` | string | **requerido** | SemVer del paquete (sin `v`). Ej: `1.2.3`. |
| `dotnet_version` | string | `10.0.x` | Versión del SDK .NET para `setup-dotnet`. |
| `nuget_source` | string | `https://api.nuget.org/v3/index.json` | Feed destino. |

| Secret | Descripción |
|---|---|
| `NUGET_API_KEY` | API key con permiso de push al feed. Los wrappers pasan `secrets: inherit`. |

**Notas de diseño** que difieren de los otros reusables:

- **Sin `runner_group`**: corre en `ubuntu-latest`. No toca la VM productiva ni el ACR.
- **`secrets` declarado** explícitamente — `NUGET_API_KEY` es `required: true`.
- **`--skip-duplicate`** evita fallar si alguien re-dispara un tag accidentalmente.

### `_reusable-npm-publish.yml`

Publica una **librería npm** del org. **No versiona**: el bump (`changeset version` o edición manual de `package.json`) se hace en el **PR del cambio**, no en este workflow. El reusable solo **publica** la versión vigente de `main` con `changeset publish`, que es **idempotente** (si la versión ya está en el registro, no hace nada). Corre en runner hosted (`ubuntu-latest`).

Soporta dos registros vía el input `npm_registry`:

- **npm público** (`https://registry.npmjs.org`, default): autentica con el secret **`NPM_TOKEN`** (requerido en este caso).
- **GitHub Packages** (`https://npm.pkg.github.com`): autentica con el **`GITHUB_TOKEN`** del propio workflow — **no requiere `NPM_TOKEN`**. El scope del paquete debe ser el **nombre del org en minúsculas** (`@cosmos-sincoerp`) y el caller debe conceder `permissions: packages: write`.

| Input | Tipo | Default | Descripción |
|---|---|---|---|
| `working_directory` | string | `.` | Directorio del `package.json`. |
| `bun_version` | string | `latest` | Versión de Bun. |
| `npm_registry` | string | `https://registry.npmjs.org` | Registro destino (npm público o `https://npm.pkg.github.com`). |
| `publish_command` | string | `bun run release` | Comando que buildea y publica (`build` + `changeset publish`). |

| Secret | Descripción |
|---|---|
| `NPM_TOKEN` | **Opcional.** Token de publish; requerido solo para registros que no sean GitHub Packages. Los callers pasan `secrets: inherit`. |

**Notas de diseño:**

- **No declara `concurrency`** — eso es responsabilidad del caller (compartir el `concurrency.group` entre caller y reusable provoca un deadlock que GitHub cancela).
- **Sin acciones de terceros** (política `allowed_actions` del org): usa el CLI de changesets (devDependency) + `git`.
- **No abre "Version Packages" PR**: el versionado vive en el PR del cambio (modelo "el reusable solo publica").

**Patrón de consumo** (workflow `release.yml` del repo librería, publicando a GitHub Packages):

```yaml
on: { push: { branches: [main] } }
permissions: { contents: read, packages: write }
concurrency: { group: release-${{ github.workflow }}, cancel-in-progress: false }
jobs:
  release:
    uses: Cosmos-SincoERP/.github/.github/workflows/_reusable-npm-publish.yml@v1
    with:
      npm_registry: https://npm.pkg.github.com
    secrets: inherit
```

### `_reusable-bump-and-tag.yml`

Calcula la siguiente versión SemVer de un paquete NuGet consultando `nuget.org`, crea y empuja el tag git correspondiente y, opcionalmente, abre un GitHub Release con notas autogeneradas. **No publica el paquete**: eso lo hace `_reusable-nuget-publish.yml`. El caller tipicamente los encadena en el mismo run (`workflow_dispatch` con dropdowns) porque un tag creado con `GITHUB_TOKEN` no dispara otros workflows del mismo repo.

| Input | Tipo | Default | Descripción |
|---|---|---|---|
| `package_id` | string | **requerido** | ID del paquete en nuget.org. Ej: `ObligacionesPorPagar.Notificaciones.Contratos`. Se hace lowercase antes de consultar el feed (la API `v3-flatcontainer` es case-insensitive en el path). |
| `tag_prefix` | string | **requerido** | Prefijo del tag git, sin la versión. Ej: `notificaciones-contratos-v` → produce `notificaciones-contratos-v1.2.3`. |
| `bump_type` | string | **requerido** | `patch`, `minor` o `major`. |
| `initial_version` | string | `0.1.0` | Versión a usar si el paquete nunca fue publicado (404 en nuget.org). |
| `create_github_release` | boolean | `false` | Si es `true`, abre un GitHub Release con `--generate-notes` apuntando al tag recién creado. |
| `nuget_source_base` | string | `https://api.nuget.org/v3-flatcontainer` | Base del feed en formato `v3-flatcontainer`. Cambiar solo para feeds privados con misma API. |

| Output | Descripción |
|---|---|
| `previous_version` | Última versión estable publicada en nuget.org antes del bump (`none` si no había ninguna). |
| `new_version` | Versión calculada por el bump (sin `v`). |
| `new_tag` | Tag completo creado (`tag_prefix + new_version`). |

**Notas de diseño:**

- **Filtra pre-releases**: la API de nuget.org incluye versiones con sufijo (`-beta`, `-rc`). El reusable filtra cualquier versión que contenga `-` antes de calcular el último estable.
- **Validación contra colisión**: aborta si el tag calculado ya existe en el repo. Detecta race conditions o tags creados manualmente fuera de banda.
- **Tag anotado**: `git tag -a` con mensaje informativo (paquete, tag, versión previa). Compatible con `gh release create --verify-tag`.
- **GitHub Release opcional**: usa `--generate-notes` para autogenerar el changelog desde el tag anterior. El primer Release de un paquete listará todos los PRs/commits del repo desde el inicio (ruido inevitable la primera vez).
- **Permisos**: requiere `contents: write` tanto en el reusable como en el caller (los permisos del caller acotan al token).
- **Sin `runner_group`**: corre en `ubuntu-latest`. Solo consume la API de nuget.org y empuja un tag.

**Patrón de consumo** desde el repo aplicativo (workflow `release-nuget.yml` con dropdown de paquete y bump):

```yaml
jobs:
  resolver:
    runs-on: ubuntu-latest
    outputs:
      package_id:   ${{ steps.map.outputs.package_id }}
      tag_prefix:   ${{ steps.map.outputs.tag_prefix }}
      project_path: ${{ steps.map.outputs.project_path }}
    steps:
      - id: map
        run: |
          # Mapea inputs.package (contratos|wolverine|...) a package_id, tag_prefix, project_path

  bump-and-tag:
    needs: resolver
    uses: Cosmos-SincoERP/.github/.github/workflows/_reusable-bump-and-tag.yml@v1
    with:
      package_id: ${{ needs.resolver.outputs.package_id }}
      tag_prefix: ${{ needs.resolver.outputs.tag_prefix }}
      bump_type:  ${{ inputs.bump_type }}
      create_github_release: true

  publish:
    needs: [resolver, bump-and-tag]
    uses: Cosmos-SincoERP/.github/.github/workflows/_reusable-nuget-publish.yml@v1
    with:
      project_path:    ${{ needs.resolver.outputs.project_path }}
      package_version: ${{ needs.bump-and-tag.outputs.new_version }}
    secrets: inherit
```

### `_reusable-nuget-publish-batch.yml`

Versiona y publica **varios paquetes NuGet en una sola corrida**, aplicando el mismo `bump_type` (`patch`/`minor`/`major`) a todos. Es la variante **batch** de `_reusable-nuget-publish.yml` (single-package): mismo verbo "publish", distinguido por el sufijo `-batch`. Resuelve el caso en que `_reusable-bump-and-tag.yml` + `_reusable-nuget-publish.yml` (single-package) obligaban a **despachar el flujo una vez por paquete**, y esas corridas se **encolaban** (mismo `concurrency.group` del caller). Es **aditivo**: aquellos dos reusables siguen válidos y sin cambios.

Internamente reusa el mismo patrón resolver → matriz de `_reusable-docker-build-push.yml`:

- **Job `resolver`** (`ubuntu-latest`): por cada paquete consulta el feed, calcula la siguiente versión estable, valida que el tag no exista y crea los tags **localmente**; luego los empuja en un **push atómico** (`git push --atomic`). Secuencial a propósito: es de segundos (curl + `git tag`) y evita la carrera de empujar tags en paralelo. Emite `packages_json` enriquecido con `package_version` por paquete.
- **Job `publish`** (matriz, `fail-fast: false`): `dotnet pack`/`push` de cada paquete **en paralelo** — donde está el ahorro de tiempo real. Que un paquete falle no aborta a los demás (`--skip-duplicate` hace idempotente el re-push de los que sí salieron).

| Input | Tipo | Default | Descripción |
|---|---|---|---|
| `packages_json` | string (JSON) | **requerido** | Array de `{ package_id, tag_prefix, project_path }`. Normalmente lo arma el `resolver` del caller filtrando el catálogo por los paquetes seleccionados. |
| `bump_type` | string | **requerido** | `patch`, `minor` o `major`. Se aplica **igual a todos** los paquetes. |
| `dotnet_version` | string | `10.0.x` | SDK .NET para `setup-dotnet`. |
| `nuget_source` | string | `https://api.nuget.org/v3/index.json` | Feed destino del `push`. |
| `nuget_source_base` | string | `https://api.nuget.org/v3-flatcontainer` | Base para consultar versiones existentes. |
| `initial_version` | string | `0.1.0` | Versión para un paquete que nunca fue publicado (404). |
| `create_github_release` | boolean | `false` | Si es `true`, abre un GitHub Release por paquete con `--generate-notes`. |

| Output | Descripción |
|---|---|
| `packages_json` | El array de entrada enriquecido con `package_version`, `previous_version` y `new_tag` por paquete. |

| Secret | Descripción |
|---|---|
| `NUGET_API_KEY` | **Requerido.** API key con permiso de push al feed. Los callers pasan `secrets: inherit`. |

**Notas de diseño:**

- **No declara `concurrency`** — lo hace el **caller** (misma razón que `_reusable-npm-publish.yml`: compartir el grupo entre caller y reusable provoca deadlock). El caller usa `cancel-in-progress: false` para no abortar un publish en curso.
- **Permisos por job**: `resolver` necesita `contents: write` (empuja tags / abre Releases); `publish` corre con `contents: read`. El caller debe conceder `contents: write` (su token acota al del reusable).
- **Reintentos**: el tag se crea **antes** del publish (igual que el single-package). Si un paquete falla en `publish`, su tag ya existe; un re-despacho con ese paquete **aborta** en el resolver. Para reintentar: borra el tag del paquete fallido y vuelve a despachar seleccionándolo (los que sí salieron son idempotentes vía `--skip-duplicate`).
- **Tope ~9 paquetes** si se usa un checkbox por paquete en el caller (límite de 10 inputs de `workflow_dispatch`).
- **Inflación de versión**: con "mismo `bump_type` para todos", marcar un paquete sin cambios igual le avanza la versión y publica un `.nupkg` redundante. La selección manual es deliberada para acotarlo.

**Patrón de consumo** desde el repo aplicativo — catálogo como única fuente de verdad + un checkbox por paquete:

```yaml
# .github/paquetes-nuget.yml
paquetes:
  - nombre: contratos            # debe coincidir con el input boolean del caller
    package_id: Foo.Contratos
    tag_prefix: contratos-v
    project_path: src/Foo.Contratos/Foo.Contratos.csproj
  - nombre: wolverine
    package_id: Foo.Wolverine
    tag_prefix: wolverine-v
    project_path: src/Foo.Wolverine/Foo.Wolverine.csproj
```

```yaml
# .github/workflows/release-nuget.yml
name: Release NuGet
on:
  workflow_dispatch:
    inputs:
      bump_type:
        description: "Tipo de bump (aplica a todos los seleccionados)"
        type: choice
        options: [patch, minor, major]
        default: patch
      contratos: { description: "Publicar contratos", type: boolean, default: false }
      wolverine: { description: "Publicar wolverine", type: boolean, default: false }

permissions:
  contents: write
concurrency:
  group: release-nuget-${{ github.workflow }}
  cancel-in-progress: false

jobs:
  resolver:
    runs-on: ubuntu-latest
    outputs:
      packages_json: ${{ steps.sel.outputs.packages_json }}
    steps:
      - uses: actions/checkout@v6
      - id: sel
        shell: bash
        env:
          # Los booleans interpolan como true/false → JSON válido.
          SELECTION_JSON: |
            {
              "contratos": ${{ inputs.contratos }},
              "wolverine": ${{ inputs.wolverine }}
            }
        run: |
          set -euo pipefail
          selected=$(yq -o=json '.paquetes' .github/paquetes-nuget.yml | jq -c \
            --argjson sel "$SELECTION_JSON" \
            '[.[] | select($sel[.nombre] == true) | {package_id, tag_prefix, project_path}]')
          if [[ "$(echo "$selected" | jq 'length')" -eq 0 ]]; then
            echo "::error::No seleccionaste ningún paquete."
            exit 1
          fi
          echo "packages_json=$selected" >> "$GITHUB_OUTPUT"

  release:
    needs: resolver
    uses: Cosmos-SincoERP/.github/.github/workflows/_reusable-nuget-publish-batch.yml@v1
    with:
      packages_json: ${{ needs.resolver.outputs.packages_json }}
      bump_type: ${{ inputs.bump_type }}
      create_github_release: true
    secrets: inherit
```

> Al agregar un paquete: añade su entrada al catálogo **y** un `boolean` con el mismo `nombre` en el caller (consecuencia de elegir checkboxes). El resto del flujo no cambia.

### `_reusable-cleanup-acr-pr.yml`

Borra tags `pr-*` del ACR. Dos modos:

- **Dirigido** (`pr_number` provisto): borra `pr-{N}` y `pr-{N}-*` en cada repo. El caller (workflow `pull_request: closed`) ya sabe que el PR cerró. Combinado con `keep_sha7`, se usa también para **cleanup intra-PR** desde el wrapper `pr-imagen-docker.yml`: cada push borra los `pr-{N}-{shaPrev}` obsoletos preservando el alias y el SHA recién publicado.
- **Barrido** (sin `pr_number`): consulta vía `gh pr view` el estado de cada PR y borra los cerrados hace más de `min_age_days`.

| Input | Tipo | Default | Descripción |
|---|---|---|---|
| `acr_name` | string | `croxpdeveus2001` | |
| `repository_prefix` | string | `oxp` | |
| `repositories_json` | string (JSON) | `[]` | Si vacío, descubre todos. |
| `pr_number` | string | `""` | Modo dirigido si se da. |
| `keep_sha7` | string | `""` | Sólo en modo dirigido. Preserva `pr-{N}` y `pr-{N}-{keep_sha7}`; borra el resto. Para cleanup intra-PR. |
| `min_age_days` | number | `7` | Solo en modo barrido. |
| `dry_run` | boolean | `false` | Lista sin borrar. |

---

## 3. Convención de tags

**Una sola fórmula** para tags inmutables:

```
{acr}.azurecr.io/{prefix}/{name}:{contexto}-{sha7}
```

`{contexto}` se calcula automáticamente desde el evento de GitHub:

| Evento | `{contexto}` | Ejemplo |
|---|---|---|
| `pull_request` | `pr-{n}` | `pr-123-abc1234` |
| `push` a `main` | `main` | `main-abc1234` |
| `workflow_dispatch` u otros | `manual` | `manual-abc1234` |

**Alias mutables** (publicados en paralelo al inmutable cuando aplica):

| Alias | Cuándo se mueve | Para qué |
|---|---|---|
| `pr-{n}` | Cada commit del PR | Que el dev haga `docker pull ...:pr-123` sin copiar el SHA. |
| `main-latest` | Cada push a `main` | Conveniencia para devs que quieren "lo último de main". |

**Promoción a otros ambientes (futuro):** `staging`, `prod` se mueven por **re-tag, no por rebuild**. Misma imagen exacta promovida vía `docker tag` + `docker push`. Esto garantiza que lo que va a prod es bit-a-bit lo que pasó staging.

---

## 4. Convenciones generales

- **Naming en ACR:** `oxp/{bounded-context}-{componente}` en kebab-case. Ej: `oxp/radicacion-comandos-api`, `oxp/radicacion-grpc-api`, `oxp/reconocimiento-procesamiento`.
- **Idioma:** los workflows, descripciones y commits van en español (alineado con `CLAUDE.md`).
- **Permisos:** todo workflow declara `permissions:` mínimo. El default global se asume `read-all` y se sube a `write` solo en steps específicos (ej: comentar PR).
- **Acciones de terceros:** versionadas con tag mayor (`@v4`). Para hardening futuro se pueden pinnear con SHA.
- **Concurrency:**
  - PR: `concurrency: { group: '${workflow}-${ref}', cancel-in-progress: true }` — si llegan 5 commits rápidos, solo el último termina.
  - Main: `cancel-in-progress: false` — nunca abortar un deploy en curso.
- **Etiquetas OCI:** `_reusable-docker-build-push` agrega `org.opencontainers.image.source/revision/created` a cada imagen para trazabilidad.

---

## 5. Onboardear un repo nuevo

Asumiendo el repo `Cosmos-SincoERP/<MiRepo>` con uno o más Dockerfiles:

1. **Declarar las imágenes** — crear `<MiRepo>/.github/imagenes-docker.yml` con la lista:
   ```yaml
   imagenes:
     - name: mirepo-comandos-api
       dockerfile: src/Comandos.API/Dockerfile
       context: .
     - name: mirepo-worker
       dockerfile: src/Worker/Dockerfile
       context: .
   ```

2. **Crear el stack de Swarm** — `<MiRepo>/deploy/stack.dev.yml` que use `${ACR_LOGIN_SERVER}`, `${REPOSITORY_PREFIX}` y `${IMAGE_TAG}` para apuntar a las imágenes.

3. **Crear los 4 wrappers** en `<MiRepo>/.github/workflows/`:
   - `pr-imagen-docker.yml` — en `pull_request`: tests → docker build/push.
   - `main-deploy-dev.yml` — en `push` a `main`: tests → docker build/push → deploy → re-tag `dev`.
   - `pr-cierre-cleanup.yml` — en `pull_request: closed`: cleanup dirigido.
   - `cleanup-acr-semanal.yml` — en `schedule`: barrido.

   Cada wrapper invoca el reusable correspondiente con `uses: Cosmos-SincoERP/.github/.github/workflows/_reusable-<x>.yml@v1`.

   **Patrón ejemplo** del wrapper de PR (con descubrimiento dinámico de la matriz desde `imagenes-docker.yml`):
   ```yaml
   jobs:
     resolver:
       runs-on: ubuntu-latest
       outputs:
         images_json: ${{ steps.read.outputs.images_json }}
       steps:
         - uses: actions/checkout@v5
         - id: read
           run: echo "images_json=$(yq -o=json '.imagenes' .github/imagenes-docker.yml | jq -c .)" >> "$GITHUB_OUTPUT"

     tests:
       uses: Cosmos-SincoERP/.github/.github/workflows/_reusable-tests-dotnet.yml@v1

     docker:
       needs: [resolver, tests]
       uses: Cosmos-SincoERP/.github/.github/workflows/_reusable-docker-build-push.yml@v1
       with:
         images_json: ${{ needs.resolver.outputs.images_json }}
   ```

4. **Validar acceso al runner** — confirmar que el repo está dentro de la org `Cosmos-SincoERP` (los runners self-hosted están a nivel organización, runner group `swarm-deploy-oxp`, labels `[azure, swarm-deploy]`).

5. **Abrir un PR de prueba** — verificar que la matriz construya, publique al ACR y comente el PR con los tags.

> Para el piloto Radicación, los wrappers ya están en `ObligacionesPorPagar.Radicacion/.github/workflows/`. Úsalos como referencia.

---

## 5b. Onboardear un front nuevo en el patrón de deploy

Asumiendo el repo `Cosmos-SincoERP/<MiFront>` con un SPA construido con Bun + Vite. **NO hay GitHub Actions secrets que configurar** — la auth a Azure se resuelve por la Managed Identity de la VM que hostea el self-hosted runner (mismo patrón que los repos .NET ya onboardeados).

1. **Storage Account: ya existe, es compartido** — los fronts del plane **no** provisionan un SA por proyecto. Todos comparten `stfrontappldeveus2001` (RG `rg-appl-dev-eus2-001`), aprovisionado una sola vez por la infra de **ApplicationPlane** (static website con SPA fallback `404 → index.html`, detrás del Front Door que sirve `/*`). Un front nuevo solo agrega su namespace bajo `$web/<app>/`; no requiere cambios de Terraform en el repo de Infraestructura del BC.

2. **Otorgar a la MI de la VM del BC acceso al SA compartido** — `Storage Blob Data Contributor` sobre `stfrontappldeveus2001` lo tiene hoy el SP de tfops, **no la MI de la VM** del BC (que es quien corre el deploy desde el self-hosted runner). Hasta que se incorpore al provisioning de ApplicationPlane, asignarlo manualmente una vez por BC (acá con OXP de ejemplo: la VM vive en el RG del BC, el SA en `rg-appl-dev-eus2-001`):

   ```bash
   MI_PRINCIPAL_ID=$(az vm show -g rg-oxp-dev-eus2-001 -n vm-oxp-dev-eus2-001 \
     --query identity.principalId -o tsv)
   SA_ID=$(az storage account show -g rg-appl-dev-eus2-001 -n stfrontappldeveus2001 \
     --query id -o tsv)
   az role assignment create \
     --assignee-object-id "$MI_PRINCIPAL_ID" \
     --assignee-principal-type ServicePrincipal \
     --role "Storage Blob Data Contributor" \
     --scope "$SA_ID"
   ```

   Cuando el patrón se generalice, incorporar esta asignación al provisioning de ApplicationPlane que crea el SA (un grant por cada MI de VM de BC que despliegue fronts).

3. **Declarar la plantilla del `env.js` en el repo del front** — crear `<working_directory>/.deploy/env.js.tmpl` con los placeholders `${VAR_NAME}` que la app necesite. Cero cambios en este repo de Infraestructura para agregar variables nuevas.

   Ejemplo mínimo para un SPA que usa SignalR + auto-save:

   ```js
   // .deploy/env.js.tmpl
   window.__APP_CONFIG__ = {
     apiBaseUrl: "${API_BASE_URL}",
     signalrHubUrl: "${SIGNALR_HUB_URL}",
     autoSaveIntervalMs: ${AUTO_SAVE_INTERVAL_MS},
   };
   ```

   Convención de mapeo a Key Vault:

   | Placeholder en template | Secret en KV (con `app_name: oxp`) |
   |---|---|
   | `${API_BASE_URL}` | `front-oxp-api-base-url` |
   | `${SIGNALR_HUB_URL}` | `front-oxp-signalr-hub-url` |
   | `${AUTO_SAVE_INTERVAL_MS}` | `front-oxp-auto-save-interval-ms` |

   **Escape hatch** — si una var del template debe leer de un secret con nombre custom (ej. uno compartido entre varios fronts), declarar `<working_directory>/.deploy/env.map`:

   ```
   # .deploy/env.map (opcional) — overrides de la convención
   LEGACY_API=shared-legacy-api-url
   FEATURE_FLAGS=front-shared-feature-flags
   ```

   Las vars no listadas siguen la convención.

4. **Sembrar los secrets en Key Vault** — para cada `${VAR_NAME}` del template, crear el secret correspondiente:

   ```bash
   KV=kv-oxp-dev-eus2-001
   APP=oxp   # mismo valor que app_name del workflow

   # Para cada placeholder: VAR_NAME → front-${APP}-var-name (lowercase, _ → -)
   az keyvault secret set --vault-name "$KV" --name "front-${APP}-api-base-url"          --value ""
   az keyvault secret set --vault-name "$KV" --name "front-${APP}-signalr-hub-url"       --value "/notificaciones/hub"
   az keyvault secret set --vault-name "$KV" --name "front-${APP}-auto-save-interval-ms" --value "10000"
   ```

   La MI de la VM ya tiene `Key Vault Secrets User` sobre el KV (lo otorga `module.key_vault.vm_secrets_user`), así que el step de lectura del workflow funciona sin cambios.

5. **Validar acceso al runner** — confirmar que el repo está dentro de la org `Cosmos-SincoERP` y autorizado en el runner group `swarm-deploy-oxp` (mismo grupo que usan los repos .NET). El workflow pide los labels `[self-hosted, azure, swarm-deploy]` — son los que ya tiene el runner provisionado por la VM.

6. **Caller workflow** — crear `<MiFront>/.github/workflows/deploy.yml`:

   ```yaml
   name: deploy

   on:
     push:
       branches: [main]

   permissions:
     contents: read

   concurrency:
     group: deploy-${{ github.ref }}
     cancel-in-progress: false

   jobs:
     deploy:
       uses: Cosmos-SincoERP/.github/.github/workflows/_reusable-deploy-front.yml@v1
       with:
         app_name: oxp                                  # 2-8 chars, alfanum minúscula
         environment: dev
         storage_account_name: stfrontappldeveus2001    # SA compartido de fronts del plane (RG rg-appl-dev-eus2-001)
         web_endpoint: https://stfrontappldeveus2001.z20.web.core.windows.net/oxp/
         key_vault_name: kv-oxp-dev-eus2-001
         runner_group: swarm-deploy-oxp                 # runner group del BC (input requerido)
   ```

   Notas:
   - **No se necesita `id-token: write`** — la auth es por Managed Identity, no OIDC.
   - **No se necesita `secrets: inherit`** — el workflow no consume ningún GH Actions secret de Azure. Si en el futuro se agrega algún secret sensible (ej. token a un servicio externo), recién ahí.
   - `cancel-in-progress: false` evita abortar deploys en curso (mismo criterio que `infra-apply`).

7. **Ajustes en el código del front** — el SPA debe cargar `env.js` antes del bundle de Vite y leer config desde `window.__APP_CONFIG__`. Ver el código del piloto `ObligacionesPorPagar.Front` como referencia (`feat/runtime-config`):
   - `index.html` agrega `<script src="/env.js"></script>` antes de `src="/main.tsx"`. En build el plugin `pinEnvJsTo(VITE_APP_BASE)` lo reescribe a `<script src="/<app_name>/env.js">` para que el browser lo resuelva bajo el prefijo del front.
   - `vite.config.ts` toma `base: process.env.VITE_RELEASE_BASE ?? '/'` para que los assets apunten a `/<app_name>/releases/<sha>/`.
   - `public/env.js` aporta defaults para `bun run dev` (no se publica al Storage; el del Storage lo arma el workflow desde la plantilla del front + KV).

8. **Abrir un PR de prueba** — el workflow se dispara al merge a `main`. Verificar:
   - Job verde, smoke test OK.
   - `https://<storage>.z20.web.core.windows.net/<app_name>/env.js` devuelve los valores resueltos.
   - `https://<storage>.z20.web.core.windows.net/<app_name>/releases/<sha>/index.html` existe.

> **Para agregar/quitar variables del `env.js`:** editar `.deploy/env.js.tmpl` en el repo del front + crear/borrar el secret correspondiente en KV. Cero cambios en este repo de Infraestructura.

---

## 6. Tirar una imagen de PR localmente

Los devs pueden usar las imágenes de un PR para sus ambientes locales antes de mergear:

```bash
# Login al ACR (una vez por sesión)
az acr login --name croxpdeveus2001

# Última imagen del PR #123 (alias mutable)
docker pull croxpdeveus2001.azurecr.io/oxp/radicacion-comandos-api:pr-123

# O un commit específico del PR (inmutable)
docker pull croxpdeveus2001.azurecr.io/oxp/radicacion-comandos-api:pr-123-abc1234
```

El comentario automático en cada PR contiene los `docker pull` listos para copiar/pegar.

---

## 7. Troubleshooting

| Síntoma | Causa probable | Diagnóstico / arreglo |
|---|---|---|
| `denied: requested access to the resource is denied` al hacer `docker push` | La MI de la VM no tiene rol `AcrPush` | Verificar con `az role assignment list --assignee <MI-principal-id>`. Aplicar PR de Terraform si falta. |
| `az login --identity` falla con `MSI: failed to acquire token` | La VM perdió la MI o no propagó el token AAD | `sudo systemctl status walinuxagent`; reiniciar la VM si es necesario. El cloud-init tiene reintentos. |
| Runner self-hosted aparece offline en GitHub | Servicio del runner detenido | SSH a la VM, `sudo systemctl status actions.runner.*`. Reiniciar con `sudo systemctl restart`. |
| Build muy lento en el primer run | Cache local frío | Normal en el primer build. Las siguientes corridas reutilizan capas. |
| `docker stack config` falla con "service references undefined variable" | Falta una variable de entorno que el compose espera | Revisar `env_vars_json` del wrapper o el `imagenes-docker.yml`. |
| El alias `pr-{n}` apunta al commit anterior | Race condition entre dos pushes seguidos | Re-correr manualmente el último workflow del PR (Re-run failed jobs / Re-run all jobs). |
| `gh pr view` falla en cleanup barrido | El `GITHUB_TOKEN` del workflow no tiene `pull-requests: read` | Verificar `permissions:` del wrapper que invoca el reusable. |

Para errores nuevos, capturar el log del job, el contexto (PR/main) y el repo afectado, y abrir un issue en este repo de Infraestructura con etiqueta `cicd`.

---

## 8. Política de retención de imágenes

El ACR está en SKU **Basic**, que no soporta retention policies nativas. La retención se implementa vía workflow:

- **Inmediato:** al cerrar un PR (merge o close), `pr-cierre-cleanup.yml` borra `pr-{n}` y todos los `pr-{n}-*`.
- **Barrido semanal:** `cleanup-acr-semanal.yml` corre los lunes 03:00 UTC y borra cualquier `pr-*` cuyo PR cerró hace más de 7 días (red de seguridad por si el cierre no disparó cleanup).
- **Imágenes `main-*` y `dev`:** no se borran automáticamente. Si el volumen crece demasiado, se evaluará subir a SKU Standard para retention policy declarativa o agregar un cleanup adicional.

Para revisar manualmente lo que se eliminaría sin borrar nada:

```bash
# Desde un workflow_dispatch del wrapper, pasar dry_run: true.
```

---

## 9. Decisión de plataforma vs decisión de bounded context

Los reusables y plantillas separan deliberadamente **forma** (decisión de plataforma, vive aquí, neutral al BC) de **valores** (decisión del bounded context, lo elige cada repo aplicativo o cada `<BC>.Infraestructura`). El repo `.github` es el lugar neutro; cada `<BC>.Infraestructura` apunta sus wrappers a `uses: Cosmos-SincoERP/.github/.github/workflows/_reusable-X.yml@v1`.

| Plataforma (vive aquí, no cambia entre BCs) | Bounded context (lo elige cada BC) |
|---|---|
| Contrato de `images_json` (`name + dockerfile + context`) | La lista concreta de imágenes |
| Fórmula de tags `{ref_context}-{sha7}` y reglas de alias mutable | — |
| Mecánica del Swarm secret versionado por sha256[:8] | El **prefijo** del Swarm secret (`swarm_secret_prefix`) |
| División hosted/self-hosted y semántica de la label del runner | La **label** concreta (`runner_label`) y el **runner group** de GitHub (`runner_group`) |
| Forma de los 4 wrappers + `imagenes-docker.yml` + `stack.yml` | Valores concretos: `acr_name`, `repository_prefix`, `key_vault_name`, `buildx_builder_name`, networks Swarm |
| Snippet `AddKeyPerFile("/run/secrets")` en .NET | — |

Si un cambio te exige tocar la columna izquierda, es una decisión de plataforma — pásalo por revisión cuidadosa porque afecta a todos los BCs. Si solo toca la columna derecha, es ajuste de BC y vive en el catálogo `bounded-contexts.yml` (entrada del BC) o en el wrapper del repo aplicativo.

### Bounded contexts registrados

> ⚠️ El catálogo declarativo y la skill de onboarding viven en `Cosmos-SincoERP/Cosmos.AgentSkills`, no en este repo. Esta tabla es **referencia humana duplicada**; la fuente de verdad está en `.claude/skills/onboard-dotnet-repo/bounded-contexts.yml` de ese otro repo. Sincronizar manualmente cuando se registre un BC nuevo.

| Key | Display name | Infra repo | ACR | Key Vault | Repo prefix | Swarm secret prefix | Buildx builder | Runner group (GitHub) | Networks Swarm |
|---|---|---|---|---|---|---|---|---|---|
| `oxp` | ObligacionesPorPagar | `Cosmos-SincoERP/ObligacionesPorPagar.Infraestructura` | `croxpdeveus2001` | `kv-oxp-dev-eus2-001` | `oxp` | `oxp` | `oxp-builder` | `swarm-deploy-oxp` | `oxp-public`, `oxp-internal` |
| `cont` | Contabilidad | `Cosmos-SincoERP/Cosmos.Contabilidad.Infraestructura` | `crcontdeveus2001` | `kv-cont-dev-eus2-001` | `cont` | `cont` | `cont-builder` | `swarm-deploy-cont` | `cont-public`, `cont-internal` |
| `impu` | Impuestos | `Cosmos-SincoERP/Cosmos.Impuestos.Infraestructura` | `crimpudeveus2001` | `kv-impu-dev-eus2-001` | `impu` | `impu` | `impu-builder` | `swarm-deploy-impu` | `impu-public`, `impu-internal` |

Para registrar un BC nuevo (Impuestos, Terceros, etc.): invocar la skill **`/provision-bc-infra`** desde el cwd del repo `Cosmos.AgentSkills`. La skill clona el repo aplicativo del BC en read-only, detecta sus dependencias Azure (OpenAI, DocIntel, Storage Blobs, RabbitMQ, Postgres) por grep de PackageReferences y appsettings, propone los módulos Terraform a incluir/excluir, y orquesta end-to-end (gh repo create, scaffold mecánico, ediciones de TF según los hallazgos, bootstrap externo Azure, runner group org-level, push inicial de main, PR de validación del primer plan, y registro del BC en este catálogo) con confirmación explícita en cada paso costoso. Es idempotente: si el flujo se interrumpe, re-invocar la skill detecta el estado y propone retomar desde donde quedó.

Para hacerlo a mano (sin la skill), las piezas viven en `.claude/skills/provision-bc-infra/`:
- `SKILL.md` — secuencia de pasos (sirve como referencia humana).
- `scripts/scaffold-bc-infra.sh` — el rebrand mecánico oxp → bc-key sobre OPP.Infraestructura.
- `scripts/investigate-app-repo.sh` — la detección de dependencias del repo aplicativo.
