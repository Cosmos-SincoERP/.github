---
status: accepted
date: 2026-05-25
deciders: [augusto-romero-arango]
consulted: []
informed: []
---

# 0002 — Políticas de repositorios: ambiente de desarrollo

## Contexto y problema

Hereda el marco general de [[0001]]. Cosmos-SincoERP opera hoy con un único ambiente: **desarrollo**. No existe ambiente de producción todavía; las políticas asociadas se documentan en [[0003]].

Pregunta de decisión: para cada práctica del catálogo de [[0001]], ¿se aplica hoy, se difiere a [[0003]], o se descarta?

## Drivers de decisión

Heredados de [[0001]]:

1. Reducción de superficie de riesgo.
2. Consistencia de gobierno entre repos.
3. Fricción mínima viable para devs.
4. Adaptación al flujo IA.

## Opciones consideradas — modelos de adopción para desarrollo

- **A. Solo Fase 0 (mitigación urgente)**: solo lo crítico (2FA, base permission, Actions allowlist, Dependabot). Sin Rulesets, sin CODEOWNERS, sin plantillas. Rápido; gaps de consistencia.
- **B. Lift-and-shift del piloto `ObligacionesPorPagar.Radicacion`**: replicar a todos los repos lo que ya tiene ese repo. Validado en uso interno; no aprovecha Rulesets org-wide.
- **C. Baseline org-wide + plantillas vendoreadas**: Fase 0 + Rulesets a nivel organización en `~DEFAULT_BRANCH` + community health files y plantillas (dependabot por stack) en `Cosmos-SincoERP/.github`. Baseline único.
- **D. Políticas como código en CI (compliance workflow)**: cumplimiento como workflow reusable. Portable; bypasseable.

## Decisión (modelo de adopción)

Se adopta el **modelo C — Baseline org-wide + plantillas vendoreadas**:

- Las prácticas marcadas como `Aplicar (org)` se materializan vía **Rulesets a nivel organización** targeting `~DEFAULT_BRANCH`.
- Las prácticas que requieren archivos por repo (`dependabot.yml`, `CODEOWNERS` específico) usan **plantillas vivas** en `Cosmos-SincoERP/.github` (defaults org-wide) o vendoreadas por repo donde se requiera personalización.
- La capa de CI/CD se construye sobre los **reusables ya existentes** en `Cosmos-SincoERP/Cosmos.PlatformWorkflows`.
- No se activa segmentación por tier en esta fase (el mecanismo de custom properties queda disponible para [[0003]]).

Esta decisión es la consecuencia natural de las decisiones por práctica que siguen.

## Decisiones por práctica

Cada práctica refiere al catálogo neutral de [[0001]] (descripción técnica detallada vive allá).

### Categoría A — Identidad y permisos de la organización

#### A.1 — 2FA obligatorio en la organización
- **Decisión**: Aplicar (org) — Fase 0.
- **Configuración**: `two_factor_requirement_enabled = true`.
- **Justificación**: la cuenta humana es la frontera de confianza última cuando agentes IA actúan en su nombre; 2FA limita el blast radius de un compromiso. Cero costo, alto valor.

#### A.2 — `default_repository_permission`
- **Decisión**: Aplicar (org) — Fase 1, con **transición**.
- **Configuración**: los miembros actuales preservan permisos administrativos vía membresía explícita en un team `founders-admins` que se crea con permiso `admin` en repos donde aplique. El `default_repository_permission` baja a `write` para que los **nuevos miembros** entren con `write` por defecto.
- **Justificación**: bajar uniformemente a `read` o `none` rompería accesos legítimos vigentes; la transición vía team explícito grandfather a los actuales sin perder el endurecimiento para nuevos.

#### A.3 — Política de creación de repositorios
- **Decisión**: Diferir a [[0003]] — bloqueado por limitación del plan Team.
- **Justificación**: la intención original (aplicar `members_can_create_public_repositories = false; members_can_create_private_repositories = true`) no es expresable en el plan Team. La API de GitHub rechaza esa combinación con HTTP 422; el único toggle granular disponible es `members_can_create_repositories` con valores `all`, `private`, o `none` — y `private` requiere plan Pro+ u Org Owner restrictivo que no aplica acá. Las opciones reales bajo Team son aceptar el riesgo (estado actual) o bloquear toda creación (rompe la autonomía privada que se quería preservar). Se difiere a [[0003]] para reevaluar con upgrade Enterprise, donde la configuración deseada es expresable nativamente. Verificado empíricamente 2026-05-26 al intentar aplicar la decisión.

#### A.4 — Política de outside collaborators
- **Decisión**: Aplicar (org) — Fase 1.
- **Configuración**: prohibidos por default; excepciones documentadas y aprobadas por un owner. Revisión periódica de la lista actual.
- **Justificación**: limita exposición externa; cada excepción debe justificarse.

#### A.5 — Security managers
- **Decisión**: Aplicar (org) — Fase 1.
- **Configuración**: asignar el rol al team de plataforma/seguridad (handle a confirmar; usar team `cosmos-platform` o el equivalente que se determine).
- **Justificación**: separa preocupaciones de seguridad sin sobre-privilegio admin general.

### Categoría B — Protección de ramas y Rulesets

#### B.1 — Require pull request before merging
- **Decisión**: Aplicar (org) — Fase 0.
- **Configuración**: Ruleset org-level targeting `~DEFAULT_BRANCH` con regla `pull_request`.
- **Justificación**: bloquea push directo a `main`; fundamento del resto de protecciones.

#### B.2 — N approvals
- **Decisión**: Aplicar — Fase 1.
- **Configuración**: `required_approving_review_count = 0` (se requiere PR, no se requiere approval para mergear).
- **Justificación**: en dev la fricción de approvals obligatorias se considera mayor que el riesgo; el equipo decide caso por caso si pide review. Reevaluar en [[0003]] para repos críticos.

#### B.3 — Dismiss stale approvals on new commits
- **Decisión**: Aplicar (org) — Fase 1.
- **Configuración**: `dismiss_stale_reviews_on_push = true`.
- **Justificación**: aunque B.2 = 0 approvals, las aprobaciones voluntarias se invalidan si el autor pushea cambios después → evita que un "último fix" entre sin re-revisión.

#### B.4 — Require review from CODEOWNERS
- **Decisión**: Aplicar (org) — Fase 1.
- **Configuración**: `require_code_owner_review = true`. La regla no fuerza tener `CODEOWNERS`; si el repo no lo tiene, no aplica; si lo tiene, enruta la revisión.
- **Justificación**: cuando un repo define CODEOWNERS (decisión C.3 por repo), la revisión se canaliza al experto del dominio. Compatible con B.2=0 approvals como única revisión requerida para archivos con owner.

#### B.5 — Require conversation resolution before merging
- **Decisión**: Aplicar (org) — Fase 1.
- **Configuración**: `required_review_thread_resolution = true`.
- **Justificación**: bajo flujo IA, los comentarios de revisores suelen ser matices que la IA podría no haber considerado; resolverlos forza ack explícito.

#### B.6 — Require signed commits
- **Decisión**: Diferir a [[0003]].
- **Justificación**: alto costo de setup (GPG/SSH en cada máquina y agente IA); valor moderado en dev. Reevaluar para repos críticos cuando exista producción.

#### B.7 — Require linear history
- **Decisión**: Aplicar (org) — Fase 1.
- **Configuración**: `required_linear_history = true`.
- **Justificación**: historial limpio; facilita bisect y revert (1 PR = 1 commit). Compatible con C.5 squash-only.

#### B.8 — Block force push
- **Decisión**: Aplicar (org) — Fase 1.
- **Configuración**: regla `non_fast_forward` en Ruleset.
- **Justificación**: protección barata contra destrucción de historial; especialmente importante bajo flujo IA.

#### B.9 — Block branch deletion
- **Decisión**: Aplicar (org) — Fase 1.
- **Configuración**: regla `deletion` en Ruleset.
- **Justificación**: evita borrado accidental del default branch.

#### B.10 — Restrict who can push to default branch
- **Decisión**: **No aplicar en dev** (decisión explícita registrada).
- **Justificación**: restringir el set de actores aumenta fricción sin valor claro en dev. Reevaluar en [[0003]] para ramas de release o repos críticos.

#### B.11 — Tag protection rules
- **Decisión**: Diferir a [[0003]].
- **Justificación**: sin releases formales productivos todavía, no hay tags estables que proteger más allá de los `@v1` de `Cosmos.PlatformWorkflows`. Reevaluar cuando exista proceso de release.

#### B.12 — Push rulesets (paths, extensiones, tamaño)
- **Decisión**: Aplicar (org) — Fase 0.
- **Configuración**: Push ruleset org-level con bloqueo de paths/extensiones (set estricto):
  - Paths: `.env*`, `*.pem`, `*.pfx`, `*.key`, `id_rsa*`, `secrets.*`, `*.cert`, `aws-credentials*`, `*.kdbx`.
  - Tamaño máximo: 50 MB por archivo.
- **Justificación**: bajo flujo IA, los agentes pueden inadvertidamente commitear secretos del contexto; este guardrail es barato y efectivo. Especialmente crítico dado que GHAS push protection no está disponible (E.6 mitigado parcialmente aquí).

#### B.13 — Default branch name uniforme (`main`)
- **Decisión**: Aplicar (org) — Fase 1 + remediar excepciones.
- **Configuración**: setear default org-wide a `main`; renombrar default de `Cosmos.Terceros` (hoy `feature/dominio`) a `main`.
- **Justificación**: predictibilidad para scripts, automatizaciones y los Rulesets que targetean `~DEFAULT_BRANCH`.

#### B.14 — Targeting por custom properties
- **Decisión**: Mecanismo adoptado (heredado del modelo D de [[0001]]); valores específicos diferidos a [[0003]].
- **Justificación**: hoy no se necesita diferenciación por tier; el baseline único es uniforme. El mecanismo queda disponible.

### Categoría C — PRs, revisión y CODEOWNERS

#### C.1 — Pull request template
- **Decisión**: Descartar.
- **Justificación**: bajo flujo IA, los templates son fáciles de rellenar trivialmente (la IA inventa secciones), lo que produce ruido auto-generado sin valor. Si se llegara a necesitar, revisitar con un template que pida información que la IA no pueda inventar (test plan ejecutado, decisiones tomadas).

#### C.2 — Issue templates
- **Decisión**: Descartar.
- **Justificación**: bajo flujo de trabajo actual, los issues no son punto de entrada principal; los agentes IA tienden a no usarlos. Sin valor justificable para imponer estructura.

#### C.3 — CODEOWNERS por dominio/servicio
- **Decisión**: Aplicar a nivel repo (sin default org-wide).
- **Configuración**: cada repo define su `CODEOWNERS` cuando exista ownership identificable. Sin plantilla heredada vía `Cosmos-SincoERP/.github`.
- **Justificación**: ownership es específico por repo y por dominio; un CODEOWNERS genérico org-wide aportaría ruido. La regla B.4 sigue activa: si el repo tiene CODEOWNERS, la revisión se enruta.

#### C.4 — Auto-merge habilitado
- **Decisión**: Aplicar — Fase 1.
- **Configuración**: habilitar `allow_auto_merge = true` en cada repo (org-wide vía bootstrap).
- **Justificación**: combinado con C.5 (squash-only) y C.6 (auto-delete), reduce latencia entre "checks verdes" y merge. Considerando B.2=0 approvals + D.1 (status checks obligatorios por stack), el bloqueante real para auto-merge son los checks de CI, no la revisión humana.

#### C.5 — Política de merge
- **Decisión**: Aplicar — Fase 1.
- **Configuración**: squash-only org-wide. Deshabilitar merge commits y rebase merging (`allow_squash_merge=true`, `allow_merge_commit=false`, `allow_rebase_merge=false`).
- **Justificación**: historial lineal con 1 PR = 1 commit en `main`. Facilita revert y bisect; bajo flujo IA, simplifica reversar PRs problemáticos.

#### C.6 — Auto-delete branch on merge
- **Decisión**: Aplicar — Fase 1.
- **Configuración**: `delete_branch_on_merge = true` org-wide vía bootstrap.
- **Justificación**: higiene; evita acumulación de cientos de ramas obsoletas que los agentes pueden crear.

#### C.7 — Convención de títulos / conventional commits
- **Decisión**: Diferir.
- **Justificación**: sin requisito inmediato de changelog automatizado, el costo de mantenimiento del enforcement supera el valor actual. Revisitar cuando se introduzca semantic-release o release-please.

#### C.8 — Draft PRs como convención
- **Decisión**: Descartar (no formalizar).
- **Justificación**: feature nativa de GitHub que cualquiera puede usar a discreción; no aporta valor formalizarla como política.

#### C.9 — Labels estándar org-wide
- **Decisión**: Diferir.
- **Justificación**: valor inmediato bajo sin necesidad de reporting cross-repo. Revisitar si surge automatización basada en labels.

### Categoría D — CI/CD y checks requeridos

#### D.1 — Status checks obligatorios
- **Decisión**: Aplicar a nivel repo (vía reusables) — Fase 1.
- **Configuración**: cada repo marca como required los checks correspondientes a su stack: build/test (.NET = `_reusable-tests-dotnet.yml`, frontend = `_reusable-tests-frontend.yml`). Los reusables de `Cosmos.PlatformWorkflows` deben exponer nombres de check estandarizados para que sean referenciables uniformemente desde Rulesets.
- **Justificación**: status checks son la barrera de calidad más confiable bajo flujo IA. No se puede forzar org-wide en Team (Required Workflows requiere Enterprise → ver D.10).

#### D.2 — Environments con required reviewers
- **Decisión**: Diferir a [[0003]].
- **Justificación**: sin ambiente productivo, los environments tienen valor limitado.

#### D.3 — Pinning de acciones
- **Decisión**: Aplicar — Fase 1, con política diferenciada por nivel de confianza del creator.
- **Configuración**:
  - **GitHub-owned (`actions/*`, `github/*`)** → tag mayor (`@v4`, `@v5`). Justificación: si GitHub mismo se compromete, el SHA pinning no protege — GitHub controla la infra del runner. Valor agregado marginal y costo de mantenimiento real (legibilidad + Dependabot bumps por SHA).
  - **Verified creators corporativos** (lista mantenida abajo) → tag mayor. Justificación: tienen procesos de release auditados, security teams y code signing. Riesgo de compromiso individual es bajo y los CVEs llegan vía Dependabot security alerts.
  - **Resto (creators individuales o no-verified)** → SHA inmutable obligatorio. Justificación: 1 PAT comprometido del mantenedor único = juego terminado (caso emblema: `tj-actions/changed-files`, marzo 2025, ~23 000 repos afectados al reasignar tags retroactivamente).
  - **Reusables internos de `Cosmos.PlatformWorkflows`** → `@v1` (referencia móvil controlada dentro del perímetro).
  - **Dependabot `github-actions` ecosystem** habilitado en todos los repos para mantener tags y SHAs al día sin intervención manual.

  Lista canónica de verified-creators-as-tag (a actualizar cuando entre un nuevo creator al portafolio):

  ```
  azure/*, microsoft/*, aws-actions/*, google-github-actions/*,
  hashicorp/*, docker/*, oven-sh/*, ruby/*, trufflesecurity/*, aquasecurity/*
  ```

- **Tooling**: `pinact` corre en bootstrap por repo, pero su salida se **filtra** para revertir cambios sobre la allowlist anterior (GitHub-owned + verified corp). Solo permanecen los SHA pinning sobre creators que sí lo requieren. La regla operativa para revisores: cualquier PR que introduzca un `uses:` fuera de la allowlist debe pinear por SHA explícitamente.
- **Justificación general**: protección contra supply chain attacks por movimiento malicioso de tags (caso `tj-actions/changed-files`, marzo 2025) **donde el riesgo es material** (creators individuales). Para creators corporativos verified y GitHub-owned, la práctica de la industria (y la posición oficial pragmática de GitHub: *"the 'Verified creator' badge is a useful signal"*) considera el tag mayor aceptable. La política diferenciada reduce ruido visual en cada workflow y costo de mantenimiento sin abandonar el caso de uso real de SHA pinning (creators individuales / no-verified).

#### D.4 — `permissions:` mínimo en `GITHUB_TOKEN`
- **Decisión**: Aplicar (org) — Fase 0.
- **Configuración**: Settings org → Actions → Workflow permissions → "Read repository contents and packages permissions" (default `read-all`). Workflows que necesiten más deben declararlo explícitamente con bloque `permissions:`.
- **Justificación**: límite del blast radius de cualquier workflow comprometido o vulnerable a injection. Los reusables de `Cosmos.PlatformWorkflows` ya declaran sus permisos explícitamente.

#### D.5 — Allowed Actions allowlist
- **Decisión**: Aplicar (org) — Fase 1.
- **Configuración**: `allowed_actions = selected`. Permitir:
  - GitHub-owned (`actions/*`, `github/*`).
  - Marketplace verified creators (Docker, Azure, AWS, Microsoft, Google, HashiCorp, etc.).
  - Lista explícita: `Cosmos-SincoERP/*` + acciones no-verificadas pero ya en uso (auditar antes de activar).
- **Justificación**: principal barrera contra agentes IA que añaden acciones de terceros sin auditar. Mantiene operación normal (verified cubre la mayoría) sin abrir puerta a acciones desconocidas.

#### D.6 — Secrets y variables a nivel organización
- **Decisión**: Aplicar (org) — Fase 1.
- **Configuración**: para secretos transversales (NUGET_API_KEY, ACR credentials, etc.) definir a nivel org con `visibility = selected_repositories` (scoping por repo). Los secretos específicos de un repo siguen viviendo en el repo.
- **Justificación**: centraliza rotación; scoping limita exposición.

#### D.7 — Reusable workflows centralizados
- **Decisión**: Aplicar — Fase 1.
- **Configuración**: documentar que nuevos workflows para los stacks cubiertos (.NET, Bun/Node, Docker Swarm, NuGet) **deben invocar** los reusables de `Cosmos-SincoERP/Cosmos.PlatformWorkflows@v1`. Workflows existentes se migran oportunistamente.
- **Justificación**: aprovecha lo construido; reduce drift y variabilidad entre repos.

#### D.8 — Concurrency control
- **Decisión**: Aplicar como buena práctica documentada — Fase 1.
- **Configuración**: convención:
  - Workflows de PR: `concurrency: group: pr-${{ github.head_ref }}-${{ github.workflow }}` + `cancel-in-progress: true`.
  - Workflows de deploy: `concurrency: group: deploy-${{ github.workflow }}-${{ inputs.environment }}` + `cancel-in-progress: false`.
- **Justificación**: ahorra runner-minutes en PRs (cancela runs obsoletas); evita carreras en deploys.

#### D.9 — OIDC / Managed Identity para deploys
- **Decisión**: Aplicar como **recomendación fuerte** (no enforcement técnico) — Fase 1.
- **Configuración**: documentar en `0002` que ningún deploy nuevo a Azure (u otro cloud) debe usar secretos long-lived (service principal con secret persistente, access key, etc.). El estándar es Managed Identity en runners self-hosted o Workload Identity Federation (OIDC) desde runners hosted. `Cosmos.PlatformWorkflows` ya implementa esto en sus reusables de deploy.
- **Mecanismo de aplicación**: revisión en code review de PRs que introducen nuevos deploys o nuevos secretos. Si en el futuro se requiere enforcement automatizado, evaluar un compliance check en CI o subir a una capa de "obligatorio" en un ADR posterior.
- **Justificación**: la práctica ya existe de facto; documentarla como recomendación fuerte fija el estándar para nuevos deploys y para revisión, sin introducir gates técnicos que requieran mantenimiento. Deploys con secrets long-lived existentes (si los hay) se migran cuando se toquen.

#### D.10 — Required workflows org-wide
- **Decisión**: Descartar baseline (no disponible en Team) → ver [[0003]] para reevaluación con upgrade Enterprise.
- **Justificación**: feature solo en GitHub Enterprise. Mitigación parcial: D.1 (status checks por stack vía reusables) + B.12 (push rulesets de paths).

### Categoría E — Seguridad y dependencias

#### E.1 — Dependabot alerts
- **Decisión**: Aplicar (org) — Fase 0.
- **Configuración**: Settings org → Code security → Dependabot alerts → Enable for all repositories.
- **Justificación**: cero fricción, gratis en Team incluso para repos privados; visibilidad inmediata de CVEs.

#### E.2 — Dependabot security updates
- **Decisión**: Aplicar (org) — Fase 0.
- **Configuración**: Settings org → Code security → Dependabot security updates → Enable for all.
- **Justificación**: cierra el loop detección→fix vía PRs automáticos. Bajo flujo IA con auto-merge habilitado (C.4) y tests verdes, mantiene el portafolio al día con baja carga humana.

#### E.3 — Dependabot version updates
- **Decisión**: Aplicar — Fase 1, plantillas por stack en `Cosmos-SincoERP/.github`.
- **Configuración**: crear plantillas `dependabot-<stack>.yml` (`.NET`, `node-bun`, `docker`, `terraform`, `github-actions`). Cada repo vendor-copia la(s) que aplican. Cadencia semanal; usar `groups:` para evitar PR storm.
- **Justificación**: mantiene dependencias al día proactivamente. Las plantillas estandarizan la configuración entre repos.

#### E.4 — Dependency review action en PRs
- **Decisión**: Aplicar a nivel repo (vía reusable) — Fase 1, con **Trivy OSS** como herramienta (no `actions/dependency-review-action`).
- **Configuración**: `_reusable-dependency-review.yml` en `Cosmos.PlatformWorkflows` corriendo `aquasecurity/trivy-action` con `scan-type: fs` y `severity: HIGH,CRITICAL` sobre el repo del PR. Cada repo lo invoca vía `security-checks.yml` y lo marca como required en su Ruleset (cuando D.1 se cierre con un mecanismo unificado de required checks).
- **Elección de herramienta**: Trivy sobre `actions/dependency-review-action`. La acción de GitHub **requiere GitHub Advanced Security (GHAS) en repos privados** (verificado empíricamente 2026-05-26: *"Dependency review is not supported on this repository. Please ensure that Dependency graph is enabled along with GitHub Advanced Security"*). GHAS solo está disponible en plan Enterprise. Trivy OSS es verified creator en Marketplace, sin licencia, mantenido activamente por Aqua Security. Cobertura equivalente para el caso de uso principal (CVE en deps), con bonus: también escanea Dockerfiles, IaC (Terraform, Kubernetes), y otros stacks no .NET.
- **Pinning**: Trivy no publica tag mayor móvil (`@v0` no existe, solo tags específicos como `@v0.36.0`). Se pinea por SHA exacto con comentario de versión. Dependabot `github-actions` ecosystem mantiene la SHA actualizada.
- **Trade-off vs `dependency-review-action`**: pierdes la integración nativa con el dependency graph y los comentarios automáticos en el PR. Ganas: funciona en Team, sin coste, cobertura más amplia. Reevaluar en [[0003]] al activarse GHAS si se decide.
- **Justificación**: bloquea PRs que introducen deps vulnerables en la puerta de entrada. Alto valor bajo flujo IA.

#### E.5 — Secret scanning para repos públicos
- **Decisión**: Documentar como activo; sin asignación formal de revisión.
- **Justificación**: GitHub ya escanea los 5 repos públicos por defecto y alerta a partners (Azure, AWS) para revocación automática. Cero configuración adicional; cero revisión periódica formalizada.

#### E.6 — Secret scanning en repos privados (mitigación open-source)
- **Decisión**: Aplicar a nivel repo (vía reusable) — Fase 1.
- **Configuración**: `_reusable-secret-scan.yml` en `Cosmos.PlatformWorkflows` corriendo **TruffleHog OSS** (`trufflesecurity/trufflehog`) con flag `--only-verified` sobre el diff del PR. Marcar como required en Ruleset de cada repo privado. Combinado con B.12 (push rulesets), cubre la brecha por falta de GHAS push protection.
- **Elección de herramienta**: TruffleHog OSS sobre gitleaks. `gitleaks-action@v2` requiere licencia comercial para organizaciones (verificado empíricamente 2026-05-26 al activar el reusable: *"[org] is an organization. License key is required."*). TruffleHog OSS es verified creator en Marketplace, sin licencia, mantenido activamente por TruffleSecurity. La flag `--only-verified` filtra falsos positivos validando los secrets con el provider (AWS, Azure, GitHub, etc.).
- **Pinning**: TruffleHog no publica tag mayor móvil (`@v3` no existe, solo tags específicos `@v3.95.3`). Se pinea por SHA exacto con comentario de versión. Dependabot `github-actions` ecosystem mantiene la SHA actualizada.
- **Justificación**: el riesgo de secretos filtrados es real; sin GHAS hay que cubrirlo. Reevaluar en [[0003]] al evaluar upgrade Enterprise.

#### E.7 — Code scanning / CodeQL
- **Decisión**: Diferir a [[0003]].
- **Justificación**: gratis en públicos pero el valor incremental sobre las prácticas adoptadas (review humano, dependency review, secret scan) se considera moderado en dev. En privados requiere GHAS. Reevaluar como conjunto en [[0003]].

#### E.8 — Private vulnerability reporting
- **Decisión**: Diferir a [[0003]].
- **Justificación**: tiene sentido cuando exista canal de respuesta estructurado y SECURITY.md (E.9 también diferido). Coherente con posponer ambos al mismo tiempo.

#### E.9 — SECURITY.md
- **Decisión**: Diferir a [[0003]].
- **Justificación**: sin canal de reporte formalizado (E.8 diferido), un `SECURITY.md` apuntando a nada aporta poco. Revisitar como conjunto.

#### E.10 — SBOM exports
- **Decisión**: Aplicar bajo demanda (sin automatización).
- **Configuración**: documentar el comando `gh api repos/<owner>/<repo>/dependency-graph/sbom` como referencia. Sin workflow recurrente.
- **Justificación**: sin requisito inmediato de compliance o auditoría, generar SBOMs continuamente solo consume runner-minutes. Disponible cuando se necesite.

#### E.11 — SSO / SAML
- **Decisión**: Descartar baseline (no disponible en Team) → ver [[0003]] para reevaluación con upgrade Enterprise.
- **Justificación**: feature solo en GitHub Enterprise. La gestión de identidades sigue manual en GitHub hasta entonces.

---

## Guía de implementación

### Pre-requisitos

- Rol `Owner` en la organización Cosmos-SincoERP.
- `gh` CLI autenticado (`gh auth status` verifica).
- Acceso de escritura a `Cosmos.PlatformWorkflows` para nuevos reusables.

### Fase 0 — Crítico, esta semana

Las prácticas marcadas Fase 0 mitigan riesgos abiertos hoy con costo bajo y reversible.

#### 1. Activar 2FA obligatorio (A.1)

UI: **Settings → Authentication security → Require two-factor authentication for everyone in the Cosmos-SincoERP organization → Save**.

```bash
gh api -X PATCH orgs/Cosmos-SincoERP \
  -f two_factor_requirement_enabled=true
```

> ⚠️ Los miembros sin 2FA serán removidos automáticamente tras un período de gracia. Comunicar al equipo con al menos 7 días de antelación.

#### 2. Aplicar `permissions:` mínimo en GITHUB_TOKEN (D.4)

UI: **Settings → Actions → General → Workflow permissions → Read repository contents and packages permissions → Save**.

```bash
gh api -X PUT orgs/Cosmos-SincoERP/actions/permissions/workflow \
  -f default_workflow_permissions=read \
  -F can_approve_pull_request_reviews=false
```

#### 3. Crear Ruleset org-level para `~DEFAULT_BRANCH` con regla mínima (B.1)

Inicial: solo `pull_request` requerido (las reglas de B.3–B.9 se añaden en Fase 1). Esto bloquea push directo a `main`.

```bash
gh api -X POST orgs/Cosmos-SincoERP/rulesets \
  --input apendices/ruleset-baseline-fase0.json
```

Ver Apéndice A1 para el JSON inicial.

#### 4. Crear Push Ruleset org-level con bloqueo de paths sensibles (B.12)

```bash
gh api -X POST orgs/Cosmos-SincoERP/rulesets \
  --input apendices/ruleset-push-protection.json
```

Ver Apéndice A1 para el JSON.

#### 5. Habilitar Dependabot alerts + security updates org-wide (E.1, E.2)

UI: **Settings → Code security and analysis → Configure security and analysis features → Enable all → Apply to all eligible repositories**.

```bash
# Habilitar Dependabot alerts para todos los repos (existentes y futuros)
gh api -X POST orgs/Cosmos-SincoERP/dependabot/alerts \
  -f vulnerability_alerts_enabled_for_new_repositories=true
gh api -X POST orgs/Cosmos-SincoERP/security/security-managers \
  # configuración análoga para security updates
```

> Verificar nombre exacto del endpoint en docs de GitHub al momento de aplicar; algunas configuraciones org-wide se activan vía UI únicamente.

### Fase 1 — Rollout estándar

#### 6. Crear repositorio `Cosmos-SincoERP/.github`

```bash
gh repo create Cosmos-SincoERP/.github --public \
  --description "Defaults org-wide y documentación de gobernanza" \
  --add-readme
```

Estructura inicial sugerida:

```
Cosmos-SincoERP/.github/
├── docs/
│   ├── adr/
│   │   ├── README.md
│   │   ├── template.md
│   │   ├── 0001-marco-gobernanza-repositorios.md
│   │   ├── 0002-politicas-repositorios-desarrollo.md
│   │   └── 0003-politicas-repositorios-produccion.md
│   └── templates/
│       ├── dependabot-dotnet.yml
│       ├── dependabot-node-bun.yml
│       ├── dependabot-docker.yml
│       ├── dependabot-terraform.yml
│       └── dependabot-github-actions.yml
└── README.md
```

> No se commitean `PULL_REQUEST_TEMPLATE.md` ni `ISSUE_TEMPLATE/*` (decisión C.1, C.2 = descartar). No se commitea `CODEOWNERS` plantilla (decisión C.3 = solo por repo). No se commitea `SECURITY.md` (decisión E.9 = diferir).

#### 7. Asignar security managers (A.5)

```bash
gh api -X PUT orgs/Cosmos-SincoERP/security-managers/teams/<team-slug>
```

`<team-slug>` = slug del team de plataforma/seguridad (crear el team antes si no existe).

#### 8. ~~Restringir creación de repos públicos (A.3)~~ — diferido a [[0003]]

La combinación deseada (`members_can_create_public_repositories=false; members_can_create_private_repositories=true`) no es expresable en el plan Team — la API responde HTTP 422. Reevaluar con upgrade Enterprise. Ver decisión A.3 actualizada arriba.

#### 9. Definir política de outside collaborators (A.4)

UI: **Settings → Member privileges → Repository invitations → Outside collaborators (configurar)**. Establecer proceso de aprobación documentado.

Auditar lista actual:

```bash
gh api orgs/Cosmos-SincoERP/outside_collaborators --jq '.[].login'
```

#### 10. Transición de `default_repository_permission` (A.2)

> **Paso de transición cuidadosa** — afecta accesos.

```bash
# 1. Crear team de grandfather con admin permission
gh api -X POST orgs/Cosmos-SincoERP/teams \
  -f name="founders-admins" \
  -f description="Miembros con admin grandfathered desde el cambio de default permission (2026-05-25)"

# 2. Listar miembros actuales y añadirlos al team
gh api orgs/Cosmos-SincoERP/members --jq '.[].login' | while read user; do
  gh api -X PUT orgs/Cosmos-SincoERP/teams/founders-admins/memberships/$user \
    -f role=member
done

# 3. Otorgar admin del team a todos los repos no archivados
gh repo list Cosmos-SincoERP --limit 200 --no-archived --json name --jq '.[].name' | while read repo; do
  gh api -X PUT orgs/Cosmos-SincoERP/teams/founders-admins/repos/Cosmos-SincoERP/$repo \
    -f permission=admin
done

# 4. Bajar default a `write`
gh api -X PATCH orgs/Cosmos-SincoERP \
  -f default_repository_permission=write
```

#### 11. Actualizar Ruleset org-level con reglas completas (B.2–B.9, B.13)

```bash
# Sustituye el ruleset de Fase 0 por la versión completa
gh api -X PUT orgs/Cosmos-SincoERP/rulesets/<ruleset-id> \
  --input apendices/ruleset-baseline-fase1.json
```

Ver Apéndice A1 para el JSON.

#### 12. Estandarizar default branch a `main` (B.13)

```bash
# A nivel org (afecta repos nuevos)
gh api -X PATCH orgs/Cosmos-SincoERP \
  -f default_branch_name=main

# Remediar excepción identificada en auditoría
gh api -X POST repos/Cosmos-SincoERP/Cosmos.Terceros/branches/feature%2Fdominio/rename \
  -f new_name=main
# Verificar y comunicar al equipo dueño del repo
```

#### 13. Actions allowlist (`selected`) — D.5

**Antes de activar, auditar acciones en uso**:

```bash
# Enumerar acciones referenciadas en workflows de todos los repos
for repo in $(gh repo list Cosmos-SincoERP --limit 200 --no-archived --json name --jq '.[].name'); do
  gh api repos/Cosmos-SincoERP/$repo/contents/.github/workflows 2>/dev/null \
    | jq -r 'if type=="array" then .[].path else empty end' 2>/dev/null \
    | while read path; do
        gh api repos/Cosmos-SincoERP/$repo/contents/$path --jq .content 2>/dev/null \
          | base64 -d 2>/dev/null \
          | grep -E '^\s+uses:' || true
      done
done | sed 's/.*uses: *//' | sort -u > acciones-en-uso.txt
```

Con el listado, identificar qué cae en verified, GitHub-owned, o requiere allowlist explícita.

```bash
# Activar selected mode
gh api -X PUT orgs/Cosmos-SincoERP/actions/permissions \
  -F enabled_repositories=all \
  -F allowed_actions=selected

# Configurar allowlist
gh api -X PUT orgs/Cosmos-SincoERP/actions/permissions/selected-actions \
  -F github_owned_allowed=true \
  -F verified_allowed=true \
  -F 'patterns_allowed[]=Cosmos-SincoERP/*' \
  -F 'patterns_allowed[]=<patrón-adicional-según-auditoría>'
```

#### 14. Bootstrap de repos: settings por repo (C.4, C.5, C.6, B.13)

Aplicar la configuración no forzable org-wide a cada repo. Ver Apéndice A4 (`bootstrap-repo.sh`).

```bash
for repo in $(gh repo list Cosmos-SincoERP --limit 200 --no-archived --json name --jq '.[].name'); do
  ./scripts/bootstrap-repo.sh Cosmos-SincoERP/$repo
done
```

El script aplica:
- `allow_squash_merge=true`, `allow_merge_commit=false`, `allow_rebase_merge=false` (C.5)
- `delete_branch_on_merge=true` (C.6)
- `allow_auto_merge=true` (C.4)

#### 15. Plantillas de Dependabot en `.github` (E.3)

Commitear las plantillas en `Cosmos-SincoERP/.github/docs/templates/dependabot-*.yml`. Ver Apéndice A2.

Cada repo copia (o el script de bootstrap copia automáticamente) la plantilla que aplique a su stack como `.github/dependabot.yml`.

#### 16. Nuevos reusables en `Cosmos.PlatformWorkflows` (D.1, E.4, E.6)

Añadir a la rama `chore/bootstrap-plataforma`:

- `_reusable-dependency-review.yml` (E.4) — corre `aquasecurity/trivy-action` con `scan-type: fs` y `severity: HIGH,CRITICAL` (reemplaza a `actions/dependency-review-action` que requiere GHAS).
- `_reusable-secret-scan.yml` (E.6) — corre `trufflesecurity/trufflehog` con `--only-verified` sobre el diff del PR.

Documentar nombres de check uniformes para que sean referenciables desde Rulesets de los repos consumidores.

#### 17. Estandarizar concurrency control en reusables (D.8)

Añadir bloque `concurrency:` a los reusables de `Cosmos.PlatformWorkflows` siguiendo la convención documentada.

#### 18. Migración de pinning a SHA para acciones de terceros (D.3)

Usar `pinact` o `ratchet`:

```bash
# Ejemplo con pinact (instalado vía aqua o brew)
pinact run -u  # actualiza tags a SHA + comentario con versión legible
```

Aplicar en cada repo activo. Habilitar Dependabot `github-actions` ecosystem en las plantillas dependabot (Apéndice A2).

#### 19. Migrar secretos transversales a nivel org (D.6)

Para cada secreto compartido (ej. `NUGET_API_KEY`, ACR push credentials):

```bash
gh api -X PUT orgs/Cosmos-SincoERP/actions/secrets/NUGET_API_KEY \
  -F encrypted_value=<value> \
  -F visibility=selected \
  -F 'selected_repository_ids[]=<repo-id-1>' \
  -F 'selected_repository_ids[]=<repo-id-2>'
```

Eliminar el secreto correspondiente de cada repo después de verificar que el org-level funciona.

### Bootstrap de un repo nuevo

Ver Apéndice A4 — `scripts/bootstrap-repo.sh`.

---

## Configuraciones no forzables org-wide en Team

| Práctica | Mecanismo de aplicación por repo |
|---|---|
| C.4 Auto-merge habilitado | `gh api -X PATCH repos/<owner>/<repo> -F allow_auto_merge=true` (incluido en bootstrap) |
| C.5 Squash-only | flags `allow_*_merge` en `gh api -X PATCH repos/...` (incluido en bootstrap) |
| C.6 Auto-delete branch | flag `delete_branch_on_merge` (incluido en bootstrap) |
| D.1 Status checks específicos del stack | cada repo configura sus required checks en su propio ruleset o branch protection |
| D.3 Pinning a SHA | mantenido por Dependabot `github-actions` ecosystem en `dependabot.yml` |
| D.7 Reusables de `Cosmos.PlatformWorkflows` | cada repo invoca con `uses: ...@v1`; convención documentada |
| D.8 Concurrency control | convención + presente en los reusables |
| D.9 OIDC / MI | configurado en los reusables; no requiere replicación por repo |
| E.3 `dependabot.yml` por stack | plantilla en `.github/docs/templates/`; copia manual o vía bootstrap |
| E.4 Dependency review check | cada repo invoca `_reusable-dependency-review.yml` y lo marca como required |
| E.6 Secret scan check | cada repo invoca `_reusable-secret-scan.yml` y lo marca como required |

---

## Diferido a [[0003]]

| Práctica | Razón |
|---|---|
| A.3 Creación de repos | Combinación deseada (públicos=false, privados=true) no expresable en Team (API rechaza 422). Reevaluar con Enterprise. |
| B.6 Signed commits | Alto costo de setup, valor moderado en dev. Reevaluar para repos críticos. |
| B.11 Tag protection | Sin releases productivos todavía. |
| D.2 Environments con required reviewers | Sin ambiente productivo. |
| D.10 Required workflows org-wide | No disponible en Team; reevaluar con upgrade Enterprise. |
| E.6 Reevaluación con GHAS | Si se sube a Enterprise, secret scanning + push protection nativo sustituye `trufflehog` reusable. |
| E.7 Code scanning / CodeQL | Reevaluar con GHAS o alternativas OSS (Semgrep) en producción. |
| E.8 Private vulnerability reporting | Coherente con activar junto con `SECURITY.md`. |
| E.9 `SECURITY.md` | Sin canal de reporte formalizado, aporta poco. |
| E.11 SSO / SAML | No disponible en Team. |

---

## Descartadas

| Práctica | Razón |
|---|---|
| C.1 Pull request template | Bajo flujo IA, templates se rellenan trivialmente; producen ruido auto-generado sin valor. |
| C.2 Issue templates | Issues no son punto de entrada principal del flujo actual; los agentes no los usan. |
| C.7 Convención de títulos / conventional commits (status: diferido, no descartado) | Sin requisito de changelog automatizado hoy. |
| C.8 Draft PRs como convención formal | Feature nativa disponible para uso discrecional; no aporta formalizarla. |
| C.9 Labels estándar org-wide (status: diferido, no descartado) | Sin necesidad de reporting cross-repo hoy. |
| D.10 Required workflows org-wide (Team) | No disponible en Team. |
| E.11 SSO / SAML (Team) | No disponible en Team. |

---

## Consecuencias

- ✅ **Riesgos críticos mitigados rápidamente**. Fase 0 cubre 2FA, push protection contra paths sensibles, require PR como bloqueo de push directo, permisos mínimos en GITHUB_TOKEN, Dependabot alerts + security updates.
- ✅ **Consistencia vía Rulesets org-wide**. Las reglas B.1–B.9, B.12 aplican uniformemente sin replicar por repo.
- ✅ **Aprovecha activos previos**. Las decisiones D.7 + D.9 reconocen y formalizan parcialmente el trabajo de `Cosmos.PlatformWorkflows`; nuevos reusables (E.4, E.6) se construyen en el mismo lugar.
- ✅ **Brecha de GHAS cubierta parcialmente**. B.12 + E.6 (TruffleHog reusable) atajan la mayoría de los casos de secretos accidentales sin requerir upgrade.
- ⚠️ **Fricción inicial controlada pero real**. Squash-only, Actions allowlist y migración de pinning a SHA introducen cambios en flujos existentes; mitigar con comunicación y periodo de gracia.
- ⚠️ **Transición de base permission es delicada**. La estrategia de grandfather vía team requiere ejecución cuidadosa; si se ejecuta mal, devs pierden accesos legítimos.
- ⚠️ **B.2=0 approvals + C.4 auto-merge**. Bajo flujo IA, la combinación permite que PRs auto-generados mergeen con solo checks verdes y sin revisión humana. Mitigaciones: D.1 (status checks obligatorios), E.4 (dependency review), E.6 (secret scan), B.5 (conversation resolution). Reevaluar para repos críticos en [[0003]].
- ⚠️ **Repos legacy heterogéneos**. El bootstrap script facilita aplicar baseline pero no migra automáticamente workflows existentes; algunos repos requerirán intervención manual.
- ⚠️ **CodeQL diferido**. El SAST queda fuera del baseline; se confía en review humano + dependency review + secret scan + push rulesets. Reevaluar en [[0003]].

---

## Apéndices

### A1 — Rulesets org-level (JSON)

#### `apendices/ruleset-baseline-fase0.json`

Ruleset inicial mínimo (Fase 0) — solo `pull_request` requerido.

```json
{
  "name": "baseline-default-branch-fase0",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false
      }
    }
  ],
  "bypass_actors": []
}
```

#### `apendices/ruleset-baseline-fase1.json`

Ruleset completo (Fase 1) — sustituye al de Fase 0.

```json
{
  "name": "baseline-default-branch",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": true,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true
      }
    },
    { "type": "required_linear_history" },
    { "type": "non_fast_forward" },
    { "type": "deletion" }
  ],
  "bypass_actors": []
}
```

#### `apendices/ruleset-push-protection.json`

Push ruleset org-level (Fase 0) — bloqueo de paths sensibles y tamaño.

```json
{
  "name": "push-protection-paths-sensibles",
  "target": "push",
  "enforcement": "active",
  "conditions": {
    "repository_name": {
      "include": ["~ALL"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "file_path_restriction",
      "parameters": {
        "restricted_file_paths": [
          ".env",
          ".env.*",
          "**/.env",
          "**/.env.*",
          "**/*.pem",
          "**/*.pfx",
          "**/*.key",
          "**/id_rsa*",
          "**/secrets.*",
          "**/*.cert",
          "**/aws-credentials*",
          "**/*.kdbx"
        ]
      }
    },
    { "type": "max_file_size",
      "parameters": { "max_file_size": 52428800 }
    }
  ],
  "bypass_actors": []
}
```

> Confirmar nombres exactos de rule types al crear (`gh api orgs/<org>/rulesets/<id>` sobre un ruleset existente sirve de referencia). Algunos campos (`max_file_size`, `file_path_restriction`) tienen variaciones entre versiones del API.

### A2 — Plantillas Dependabot por stack

#### `docs/templates/dependabot-dotnet.yml`

```yaml
version: 2
updates:
  - package-ecosystem: "nuget"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 10
    groups:
      microsoft:
        patterns: ["Microsoft.*", "System.*"]
      tests:
        patterns: ["xunit*", "Moq*", "FluentAssertions*", "Bogus*"]

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

#### `docs/templates/dependabot-node-bun.yml`

```yaml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 10
    groups:
      types:
        patterns: ["@types/*"]
      eslint:
        patterns: ["eslint*", "@typescript-eslint/*"]

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

#### `docs/templates/dependabot-docker.yml`

```yaml
version: 2
updates:
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

#### `docs/templates/dependabot-terraform.yml`

```yaml
version: 2
updates:
  - package-ecosystem: "terraform"
    directory: "/"
    schedule:
      interval: "weekly"

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

#### `docs/templates/dependabot-github-actions.yml`

Para repos que solo tienen workflows (como `Cosmos.PlatformWorkflows`):

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

### A3 — Reusable workflows nuevos

Estructura sugerida para añadir a `Cosmos-SincoERP/Cosmos.PlatformWorkflows/.github/workflows/`.

#### `_reusable-dependency-review.yml`

```yaml
name: Dependency Review

on:
  workflow_call:
    inputs:
      fail-on-severity:
        type: string
        default: "high"
      deny-licenses:
        type: string
        default: "GPL-3.0, AGPL-3.0"

permissions:
  contents: read
  pull-requests: write

jobs:
  dependency-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<sha>  # pinear vía pinact
      - uses: actions/dependency-review-action@<sha>
        with:
          fail-on-severity: ${{ inputs.fail-on-severity }}
          deny-licenses: ${{ inputs.deny-licenses }}
          comment-summary-in-pr: always
```

#### `_reusable-secret-scan.yml`

```yaml
name: Secret Scan (gitleaks)

on:
  workflow_call:
    inputs:
      config-path:
        type: string
        default: ""

permissions:
  contents: read
  pull-requests: write

jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<sha>
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@<sha>
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITLEAKS_CONFIG: ${{ inputs.config-path }}
```

### A4 — Bootstrap script

#### `scripts/bootstrap-repo.sh`

```bash
#!/usr/bin/env bash
# Aplica baseline de Cosmos a un repo (settings no forzables org-wide).
# Uso: ./bootstrap-repo.sh <owner>/<repo>

set -euo pipefail

REPO="$1"

echo "→ Aplicando baseline a $REPO"

# C.4, C.5, C.6: merge style + auto-merge + auto-delete branch
gh api -X PATCH "repos/$REPO" \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true \
  -F allow_auto_merge=true \
  -F squash_merge_commit_title="PR_TITLE" \
  -F squash_merge_commit_message="PR_BODY"

# E.3: copiar dependabot.yml según stack
# (detección heurística — ajustar)
if [ -f <(gh api "repos/$REPO/contents/.csproj" 2>/dev/null) ] || \
   gh api "repos/$REPO/contents" --jq '.[].name' | grep -qE '\.csproj|\.sln'; then
  STACK="dotnet"
elif gh api "repos/$REPO/contents" --jq '.[].name' | grep -q "package.json"; then
  STACK="node-bun"
elif gh api "repos/$REPO/contents" --jq '.[].name' | grep -qiE "Dockerfile"; then
  STACK="docker"
else
  STACK="github-actions"
fi

echo "  Stack detectado: $STACK"

# Subir plantilla dependabot si no existe en el repo
if ! gh api "repos/$REPO/contents/.github/dependabot.yml" 2>/dev/null >/dev/null; then
  TEMPLATE_URL="https://raw.githubusercontent.com/Cosmos-SincoERP/.github/main/docs/templates/dependabot-${STACK}.yml"
  echo "  Copiando dependabot-${STACK}.yml"
  # (mecanismo de copia: crear PR vía API o usar gh-action de sync)
fi

echo "✓ $REPO listo"
```

> El script es referencia; ajustar detección de stack según necesidad y mecanismo de copia preferido (PR automatizado vs sync action).

---

## Referencias

- [[0001]] — Marco de gobernanza y políticas de repositorios.
- [[0003]] — Políticas para ambiente de producción.
- `Cosmos-SincoERP/Cosmos.PlatformWorkflows` — workflows reutilizables.
- `Cosmos-SincoERP/ObligacionesPorPagar.Radicacion` — piloto interno con branch protection.
- [GitHub Docs — Organization Rulesets](https://docs.github.com/en/organizations/managing-organization-settings/managing-rulesets-for-repositories-in-your-organization)
- [GitHub Docs — Push Rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets#restrict-file-paths)
- [`actions/dependency-review-action`](https://github.com/actions/dependency-review-action)
- [`gitleaks/gitleaks-action`](https://github.com/gitleaks/gitleaks-action)
- [`pinact`](https://github.com/suzuki-shunsuke/pinact) — pinning automatizado a SHA.
