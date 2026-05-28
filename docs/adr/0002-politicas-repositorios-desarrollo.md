---
status: accepted
date: 2026-05-25
deciders: [augusto-romero-arango]
consulted: []
informed: []
---

# 0002 — Políticas de repositorios: ambiente de desarrollo

## Contexto y problema

Hereda el marco general de [[0001]]. La organización opera hoy con un único ambiente: **desarrollo**. No existe ambiente de producción todavía; las políticas asociadas se documentan en [[0003]].

Pregunta de decisión: para cada práctica del catálogo de [[0001]], ¿se aplica hoy, se difiere a [[0003]], o se descarta?

## Drivers de decisión

Heredados de [[0001]]:

1. Reducción de superficie de riesgo.
2. Consistencia de gobierno entre repos.
3. Fricción mínima viable para devs.
4. Adaptación al flujo IA.

## Opciones consideradas — modelos de adopción para desarrollo

- **A. Solo Fase 0 (mitigación urgente)**: solo lo crítico (2FA, base permission, Actions allowlist, Dependabot). Sin Rulesets, sin CODEOWNERS, sin plantillas. Rápido; gaps de consistencia.
- **B. Lift-and-shift de un piloto interno**: replicar a todos los repos lo que ya tiene un repo de referencia con configuración madura. Validado en uso; no aprovecha Rulesets org-wide.
- **C. Baseline org-wide + plantillas vendoreadas**: Fase 0 + Rulesets a nivel organización en `~DEFAULT_BRANCH` + community health files y plantillas (dependabot por stack) en el repo `.github` de la org. Baseline único.
- **D. Políticas como código en CI (compliance workflow)**: cumplimiento como workflow reusable. Portable; bypasseable.

## Decisión (modelo de adopción)

Se adopta el **modelo C — Baseline org-wide + plantillas vendoreadas**:

- Las prácticas marcadas como `Aplicar (org)` se materializan vía **Rulesets a nivel organización** targeting `~DEFAULT_BRANCH`.
- Las prácticas que requieren archivos por repo (`dependabot.yml`, `CODEOWNERS` específico) usan **plantillas vivas** en el repo `.github` de la org (defaults org-wide) o vendoreadas por repo donde se requiera personalización.
- La capa de CI/CD se construye sobre **reusable workflows centralizados** consumidos vía `uses:` desde cada repo.
- No se activa segmentación por tier en esta fase (el mecanismo de custom properties queda disponible para [[0003]]).

Esta decisión es la consecuencia natural de las decisiones por práctica que siguen.

## Decisiones por práctica

Cada práctica refiere al catálogo neutral de [[0001]] (descripción técnica detallada vive allá).

### Categoría A — Identidad y permisos de la organización

#### A.1 — 2FA obligatorio en la organización
- **Decisión**: Aplicar (org) — Fase 0.
- **Justificación**: la cuenta humana es la frontera de confianza última cuando agentes IA actúan en su nombre; 2FA limita el blast radius de un compromiso. Cero costo, alto valor.

#### A.2 — `default_repository_permission`
- **Decisión**: Aplicar (org) — Fase 1, con **transición**.
- **Aproximación**: bajar el default para nuevos miembros preservando accesos de miembros actuales vía membership explícita en un team con permisos administrativos. Evita romper accesos legítimos vigentes sin perder el endurecimiento para nuevos.
- **Justificación**: bajar uniformemente sin transición rompería accesos legítimos vigentes; la estrategia de grandfather permite endurecer para nuevos sin disrupción.

#### A.3 — Política de creación de repositorios
- **Decisión**: Diferir a [[0003]] — bloqueado por limitación del plan Team.
- **Justificación**: la intención original (restringir creación pública preservando creación privada) no es expresable en el plan Team; los toggles granulares disponibles no permiten esa combinación. Las opciones reales bajo Team son aceptar el riesgo (estado actual) o bloquear toda creación (rompe la autonomía privada que se quería preservar). Se difiere a [[0003]] para reevaluar con upgrade Enterprise.
- **Nota**: esta entrada cubre la *restricción de quién puede crear* repos. La *habilitación del proceso* de creación conforme (golden path por arquetipo) se decide en [[0004]] y es ortogonal a esta restricción.

#### A.4 — Política de outside collaborators
- **Decisión**: Aplicar (org) — Fase 1.
- **Aproximación**: prohibidos por default; excepciones documentadas y aprobadas por un owner. Revisión periódica de la lista actual.
- **Justificación**: limita exposición externa; cada excepción debe justificarse.

#### A.5 — Security managers
- **Decisión**: Aplicar (org) — Fase 1.
- **Aproximación**: asignar el rol a un team con foco en plataforma/seguridad.
- **Justificación**: separa preocupaciones de seguridad sin sobre-privilegio admin general.

### Categoría B — Protección de ramas y Rulesets

#### B.1 — Require pull request before merging
- **Decisión**: Aplicar (org) — Fase 0.
- **Aproximación**: Ruleset org-level targeting `~DEFAULT_BRANCH` con regla `pull_request`.
- **Justificación**: bloquea push directo a `main`; fundamento del resto de protecciones.

#### B.2 — N approvals
- **Decisión**: Aplicar — Fase 1.
- **Aproximación**: 0 approvals requeridas (se requiere PR, no se requiere approval para mergear).
- **Justificación**: en dev la fricción de approvals obligatorias se considera mayor que el riesgo; el equipo decide caso por caso si pide review. Reevaluar en [[0003]] para repos críticos.

#### B.3 — Dismiss stale approvals on new commits
- **Decisión**: Aplicar (org) — Fase 1.
- **Justificación**: aunque B.2 = 0 approvals, las aprobaciones voluntarias se invalidan si el autor pushea cambios después → evita que un "último fix" entre sin re-revisión.

#### B.4 — Require review from CODEOWNERS
- **Decisión**: Aplicar (org) — Fase 1.
- **Aproximación**: la regla se activa sin forzar tener `CODEOWNERS`; si el repo no lo tiene, no aplica; si lo tiene, enruta la revisión.
- **Justificación**: cuando un repo define CODEOWNERS (decisión C.3 por repo), la revisión se canaliza al experto del dominio.

#### B.5 — Require conversation resolution before merging
- **Decisión**: Aplicar (org) — Fase 1.
- **Justificación**: bajo flujo IA, los comentarios de revisores suelen ser matices que la IA podría no haber considerado; resolverlos forza ack explícito.

#### B.6 — Require signed commits
- **Decisión**: Diferir a [[0003]].
- **Justificación**: alto costo de setup (GPG/SSH en cada máquina y agente IA); valor moderado en dev. Reevaluar para repos críticos cuando exista producción.

#### B.7 — Require linear history
- **Decisión**: Aplicar (org) — Fase 1.
- **Justificación**: historial limpio; facilita bisect y revert (1 PR = 1 commit). Compatible con C.5 squash-only.

#### B.8 — Block force push
- **Decisión**: Aplicar (org) — Fase 1.
- **Justificación**: protección barata contra destrucción de historial; especialmente importante bajo flujo IA.

#### B.9 — Block branch deletion
- **Decisión**: Aplicar (org) — Fase 1.
- **Justificación**: evita borrado accidental del default branch.

#### B.10 — Restrict who can push to default branch
- **Decisión**: **No aplicar en dev** (decisión explícita registrada).
- **Justificación**: restringir el set de actores aumenta fricción sin valor claro en dev. Reevaluar en [[0003]] para ramas de release o repos críticos.

#### B.11 — Tag protection rules
- **Decisión**: Diferir a [[0003]].
- **Justificación**: sin releases formales productivos todavía, no hay tags estables que proteger más allá de los `@v1` de los reusables internos. Reevaluar cuando exista proceso de release.

#### B.12 — Push rulesets (paths, extensiones, tamaño)
- **Decisión**: Aplicar (org) — Fase 0.
- **Aproximación**: Push ruleset org-level con bloqueo de paths típicos de secretos (`.env*`, claves privadas, certificados, archivos de credenciales) y un tamaño máximo razonable por archivo.
- **Justificación**: bajo flujo IA, los agentes pueden inadvertidamente commitear secretos del contexto; este guardrail es barato y efectivo. Especialmente crítico dado que GHAS push protection no está disponible (E.6 mitigado parcialmente aquí).

#### B.13 — Default branch name uniforme
- **Decisión**: Aplicar (org) — Fase 1 + remediar excepciones.
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
- **Aproximación**: cada repo define su `CODEOWNERS` cuando exista ownership identificable. Sin plantilla heredada org-wide.
- **Justificación**: ownership es específico por repo y por dominio; un CODEOWNERS genérico org-wide aportaría ruido. La regla B.4 sigue activa: si el repo tiene CODEOWNERS, la revisión se enruta.

#### C.4 — Auto-merge habilitado
- **Decisión**: Aplicar — Fase 1.
- **Aproximación**: habilitar org-wide vía bootstrap de cada repo.
- **Justificación**: combinado con C.5 (squash-only) y C.6 (auto-delete), reduce latencia entre "checks verdes" y merge. Considerando B.2=0 approvals + D.1 (status checks obligatorios), el bloqueante real para auto-merge son los checks de CI, no la revisión humana.

#### C.5 — Política de merge
- **Decisión**: Aplicar — Fase 1.
- **Aproximación**: squash-only org-wide; deshabilitar merge commits y rebase merging.
- **Justificación**: historial lineal con 1 PR = 1 commit en `main`. Facilita revert y bisect; bajo flujo IA, simplifica reversar PRs problemáticos.

#### C.6 — Auto-delete branch on merge
- **Decisión**: Aplicar — Fase 1.
- **Aproximación**: habilitar org-wide vía bootstrap de cada repo.
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
- **Aproximación**: cada repo marca como required los checks correspondientes a su stack (build/test por tecnología). Los reusables exponen nombres de check estandarizados para que sean referenciables uniformemente desde Rulesets.
- **Justificación**: status checks son la barrera de calidad más confiable bajo flujo IA. No se puede forzar org-wide en Team (Required Workflows requiere Enterprise → ver D.10).

#### D.2 — Environments con required reviewers
- **Decisión**: Diferir a [[0003]].
- **Justificación**: sin ambiente productivo, los environments tienen valor limitado.

#### D.3 — Pinning de acciones
- **Decisión**: Aplicar — Fase 1, con política diferenciada por nivel de confianza del creator.
- **Aproximación**:
  - **GitHub-owned y creators corporativos verified** → tag mayor móvil aceptable. Tienen procesos de release auditados y los CVEs llegan vía Dependabot security alerts.
  - **Creators individuales o no-verified** → SHA inmutable obligatorio. Un PAT comprometido del mantenedor único puede reasignar tags retroactivamente (caso `tj-actions/changed-files`, marzo 2025).
  - **Reusables internos** → referencia móvil controlada dentro del perímetro.
  - **Dependabot `github-actions` ecosystem** habilitado para mantener tags y SHAs al día sin intervención manual.
- **Justificación**: protección contra supply chain attacks por movimiento malicioso de tags **donde el riesgo es material** (creators individuales). Para creators corporativos verified y GitHub-owned, el tag mayor es aceptable. La política diferenciada reduce ruido visual y costo de mantenimiento sin abandonar el caso de uso real de SHA pinning.

#### D.4 — `permissions:` mínimo en `GITHUB_TOKEN`
- **Decisión**: Aplicar (org) — Fase 0.
- **Aproximación**: default org-wide a `read`. Workflows que necesiten más deben declararlo explícitamente con bloque `permissions:`.
- **Justificación**: límite del blast radius de cualquier workflow comprometido o vulnerable a injection.

#### D.5 — Allowed Actions allowlist
- **Decisión**: Aplicar (org) — Fase 1.
- **Aproximación**: modo `selected`. Permitir GitHub-owned + Marketplace verified creators + lista explícita de patrones internos y acciones no-verificadas ya en uso (auditar antes de activar).
- **Justificación**: principal barrera contra agentes IA que añaden acciones de terceros sin auditar. Mantiene operación normal (verified cubre la mayoría) sin abrir puerta a acciones desconocidas.

#### D.6 — Secrets y variables a nivel organización
- **Decisión**: Aplicar (org) — Fase 1.
- **Aproximación**: secretos transversales definidos a nivel org con scoping por repo (`visibility = selected_repositories`). Los secretos específicos de un repo siguen viviendo en el repo.
- **Justificación**: centraliza rotación; scoping limita exposición.

#### D.7 — Reusable workflows centralizados
- **Decisión**: Aplicar — Fase 1.
- **Aproximación**: nuevos workflows para los stacks cubiertos **deben invocar** los reusables centralizados. Workflows existentes se migran vía sync workflow.
- **Justificación**: aprovecha lo construido; reduce drift y variabilidad entre repos. Alinea con la convención de GitHub (community-health + reusables org-wide en el repo especial `.github`) y permite el sync automatizado.

#### D.8 — Concurrency control
- **Decisión**: Aplicar como buena práctica documentada — Fase 1.
- **Aproximación**: convención por tipo de workflow:
  - Workflows de PR: agrupados por rama + workflow, con `cancel-in-progress`.
  - Workflows de deploy: agrupados por environment, sin cancel-in-progress.
- **Justificación**: ahorra runner-minutes en PRs (cancela runs obsoletas); evita carreras en deploys.

#### D.9 — OIDC / Managed Identity para deploys
- **Decisión**: Aplicar como **recomendación fuerte** (no enforcement técnico) — Fase 1.
- **Aproximación**: ningún deploy nuevo a cloud debe usar secretos long-lived. El estándar es Managed Identity en runners self-hosted o Workload Identity Federation (OIDC) desde runners hosted. Los reusables de deploy ya implementan esto.
- **Mecanismo de aplicación**: revisión en code review de PRs que introducen nuevos deploys o nuevos secretos. Si en el futuro se requiere enforcement automatizado, evaluar un compliance check en CI o subir a una capa de "obligatorio" en un ADR posterior.
- **Justificación**: la práctica ya existe de facto; documentarla como recomendación fuerte fija el estándar para nuevos deploys y para revisión, sin introducir gates técnicos que requieran mantenimiento.

#### D.10 — Required workflows org-wide
- **Decisión**: Descartar baseline (no disponible en Team) → ver [[0003]] para reevaluación con upgrade Enterprise.
- **Justificación**: feature solo en GitHub Enterprise. Mitigación parcial: D.1 (status checks por stack vía reusables) + B.12 (push rulesets de paths).

### Categoría E — Seguridad y dependencias

#### E.1 — Dependabot alerts
- **Decisión**: Aplicar (org) — Fase 0.
- **Justificación**: cero fricción, gratis en Team incluso para repos privados; visibilidad inmediata de CVEs.

#### E.2 — Dependabot security updates
- **Decisión**: Aplicar (org) — Fase 0.
- **Justificación**: cierra el loop detección→fix vía PRs automáticos. Bajo flujo IA con auto-merge habilitado (C.4) y tests verdes, mantiene el portafolio al día con baja carga humana.

#### E.3 — Dependabot version updates
- **Decisión**: Aplicar — Fase 1, plantillas por stack vendoreadas en el repo `.github` de la org con **propagación automatizada vía sync workflow**.
- **Aproximación**: plantillas canónicas por stack (.NET, Node-Bun, Docker, Terraform, GitHub Actions). Cada repo consumidor recibe la(s) que aplican como su `.github/dependabot.yml` con header marcador "Managed by Cosmos-SincoERP/.github — do not edit manually". El sync workflow lee un manifest de consumidores y abre un PR en cada repo al cambiar una plantilla.
- **Política de agrupación**: bundle agresivo por ecosystem con subgrupos semánticos cuando aporten claridad de revisión; cadencia semanal distribuida por ecosystem para descargar CI. Security updates (E.2) son canal independiente y no se ven afectados por estos límites.
- **Justificación**: mantiene dependencias al día proactivamente. Plantillas + sync centralizado convierten cambios globales en un solo PR en el repo de governance, no N PRs manuales en N repos. Drift detectable vía cron.

#### E.4 — Dependency review action en PRs
- **Decisión**: Aplicar a nivel repo (vía reusable) — Fase 1, con **herramienta OSS** (no la action oficial de GitHub).
- **Aproximación**: reusable centralizado corriendo un scanner OSS (con severidad alta/crítica). Cada repo lo invoca y lo marca como required.
- **Justificación de elección de herramienta**: la action oficial `actions/dependency-review-action` **requiere GitHub Advanced Security (GHAS) en repos privados** (verificación empírica al activarla). GHAS solo está disponible en plan Enterprise. La alternativa OSS elegida es verified creator en Marketplace, sin licencia, con cobertura equivalente para CVEs en dependencias y bonus de cobertura adicional (Dockerfiles, IaC). Reevaluar en [[0003]] al activarse GHAS.
- **Justificación general**: bloquea PRs que introducen deps vulnerables en la puerta de entrada. Alto valor bajo flujo IA.

#### E.5 — Secret scanning para repos públicos
- **Decisión**: Documentar como activo; sin asignación formal de revisión.
- **Justificación**: GitHub ya escanea los repos públicos por defecto y alerta a partners para revocación automática. Cero configuración adicional.

#### E.6 — Secret scanning en repos privados (mitigación open-source)
- **Decisión**: Aplicar a nivel repo (vía reusable) — Fase 1.
- **Aproximación**: reusable centralizado corriendo un scanner OSS con verificación de validez (`--only-verified` o equivalente) sobre el diff del PR. Marcar como required en cada repo privado. Combinado con B.12 (push rulesets), cubre la brecha por falta de GHAS push protection.
- **Justificación de elección de herramienta**: la primera opción evaluada requería licencia comercial para organizaciones (verificación empírica al activarla). La alternativa OSS elegida es verified creator en Marketplace, sin licencia, con filtro de verificación que reduce falsos positivos.
- **Justificación general**: el riesgo de secretos filtrados es real; sin GHAS hay que cubrirlo. Reevaluar en [[0003]] al evaluar upgrade Enterprise.

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
- **Justificación**: sin requisito inmediato de compliance o auditoría, generar SBOMs continuamente solo consume runner-minutes. Disponible cuando se necesite vía la API nativa de GitHub.

#### E.11 — SSO / SAML
- **Decisión**: Descartar baseline (no disponible en Team) → ver [[0003]] para reevaluación con upgrade Enterprise.
- **Justificación**: feature solo en GitHub Enterprise. La gestión de identidades sigue manual en GitHub hasta entonces.

---

## Diferido a [[0003]]

| Práctica | Razón |
|---|---|
| A.3 Creación de repos | Combinación deseada no expresable en Team. Reevaluar con Enterprise. |
| B.6 Signed commits | Alto costo de setup, valor moderado en dev. Reevaluar para repos críticos. |
| B.11 Tag protection | Sin releases productivos todavía. |
| D.2 Environments con required reviewers | Sin ambiente productivo. |
| D.10 Required workflows org-wide | No disponible en Team; reevaluar con upgrade Enterprise. |
| E.6 Reevaluación con GHAS | Si se sube a Enterprise, secret scanning + push protection nativo sustituye el reusable OSS. |
| E.7 Code scanning / CodeQL | Reevaluar con GHAS o alternativas OSS en producción. |
| E.8 Private vulnerability reporting | Coherente con activar junto con `SECURITY.md`. |
| E.9 `SECURITY.md` | Sin canal de reporte formalizado, aporta poco. |
| E.11 SSO / SAML | No disponible en Team. |

---

## Descartadas

| Práctica | Razón |
|---|---|
| C.1 Pull request template | Bajo flujo IA, templates se rellenan trivialmente; producen ruido auto-generado sin valor. |
| C.2 Issue templates | Issues no son punto de entrada principal del flujo actual; los agentes no los usan. |
| C.8 Draft PRs como convención formal | Feature nativa disponible para uso discrecional; no aporta formalizarla. |
| D.10 Required workflows org-wide (Team) | No disponible en Team. |
| E.11 SSO / SAML (Team) | No disponible en Team. |

---

## Consecuencias

- ✅ **Riesgos críticos mitigados rápidamente**. Fase 0 cubre 2FA, push protection contra paths sensibles, require PR como bloqueo de push directo, permisos mínimos en GITHUB_TOKEN, Dependabot alerts + security updates.
- ✅ **Consistencia vía Rulesets org-wide**. Las reglas B.1–B.9, B.12 aplican uniformemente sin replicar por repo.
- ✅ **Brecha de GHAS cubierta parcialmente**. B.12 + E.6 (reusable OSS) atajan la mayoría de los casos de secretos accidentales sin requerir upgrade.
- ⚠️ **Fricción inicial controlada pero real**. Squash-only, Actions allowlist y migración de pinning a SHA introducen cambios en flujos existentes; mitigar con comunicación y periodo de gracia.
- ⚠️ **Transición de base permission es delicada**. La estrategia de grandfather vía team requiere ejecución cuidadosa; si se ejecuta mal, devs pierden accesos legítimos.
- ⚠️ **B.2=0 approvals + C.4 auto-merge**. Bajo flujo IA, la combinación permite que PRs auto-generados mergeen con solo checks verdes y sin revisión humana. Mitigaciones: D.1 (status checks obligatorios), E.4 (dependency review), E.6 (secret scan), B.5 (conversation resolution). Reevaluar para repos críticos en [[0003]].
- ⚠️ **CodeQL diferido**. El SAST queda fuera del baseline; se confía en review humano + dependency review + secret scan + push rulesets. Reevaluar en [[0003]].
