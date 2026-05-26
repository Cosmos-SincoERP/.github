---
status: accepted
date: 2026-05-25
deciders: [augusto-romero-arango]
consulted: []
informed: []
---

# 0001 — Marco de gobernanza y políticas de repositorios

## Contexto y problema

La organización **Cosmos-SincoERP** en GitHub.com opera bajo plan **Team** con 49 repositorios activos (5 públicos, 44 privados), todos con actividad reciente (push en los últimos 6 meses). El portafolio incluye principalmente C# (17 repos), TypeScript (7), HCL/Terraform (5), Dockerfile (3) y otros lenguajes (14). Hay entre 10 y 30 desarrolladores trabajando, y una porción creciente del código se produce con asistencia de IA.

Una auditoría de la organización y de los 5 repos más activos (mayo de 2026) reveló la siguiente línea base:

| Dimensión | Estado actual |
|---|---|
| 2FA obligatorio en la organización | ❌ No requerido |
| `default_repository_permission` | `admin` (cualquier miembro es admin de cualquier repo) |
| Política de Actions org-wide | `enabled_repositories: all`, `allowed_actions: all` (sin restricción) |
| Rulesets a nivel organización | 0 |
| Custom properties definidas | Ninguna |
| Security managers | Ninguno asignado |
| Secretos a nivel organización | 0 |
| Branch protection en repos muestreados (5) | 1 de 5 (`ObligacionesPorPagar.Radicacion`) |
| CODEOWNERS en repos muestreados (5) | 0 de 5 |
| `dependabot.yml` en repos muestreados (5) | 0 de 5 |
| Vulnerability alerts en repos muestreados (5) | 0 de 5 |
| Auto-delete branch on merge | 0 de 5 |
| Estrategias de merge habilitadas | Las 3 (squash, merge commit, rebase) en los 5 |

**Activos previos relevantes** para no proponer trabajo duplicado:

- **`Cosmos-SincoERP/Cosmos.PlatformWorkflows`** (rama `chore/bootstrap-plataforma`) provee 8 workflows reutilizables (.NET tests, frontend tests, Docker build/push, deploy Swarm, deploy front, NuGet publish, bump-and-tag, cleanup ACR), todos con `permissions:` declarados explícitamente (least privilege), runners hosted + self-hosted con Azure Managed Identity (sin secretos long-lived) y convención de consumo via `@v1`. **No** incluye CODEOWNERS, `dependabot.yml`, templates de PR/issue ni SECURITY.md.
- **`Cosmos-SincoERP/ObligacionesPorPagar.Radicacion`** es el único repo con branch protection en `main`, 1 ruleset y 6 workflows; funciona como piloto interno natural.
- **`Cosmos-SincoERP/.github`** no existe todavía (404 confirmado vía `gh api`). GitHub usa este repo especial para defaults org-wide (community health files: CODEOWNERS, PR template, SECURITY.md, dependabot.yml) que se aplican a cualquier repo que no tenga el suyo propio.

**Realidad operativa**: alto volumen de PRs, parte sustancial generada o iniciada con IA. Esto cambia el cálculo de algunas prácticas (la revisión humana sigue siendo la barrera principal de calidad, el scanning automático sube su valor, y la consistencia de plantillas baja su costo porque la IA puede rellenarlas).

**Hoy solo existe ambiente de desarrollo**. Producción se materializará después; las políticas asociadas a producción se documentan por separado en [[0003]].

**Pregunta de decisión**: ¿qué marco operativo de gobernanza de repositorios adopta Cosmos-SincoERP, qué catálogo de prácticas se considera relevante evaluar, y bajo qué criterios y principios se decidirá la aplicación de cada una?

## Drivers de decisión

Las prácticas del catálogo se evaluarán según los siguientes drivers, en este orden de aplicación (cuando entren en tensión):

1. **Reducción de superficie de riesgo** — priorizar prácticas que mitigan riesgos sistémicos (identidad, secretos, dependencias, supply chain) sobre las que solo aportan consistencia estética.
2. **Consistencia de gobierno entre repos** — las prácticas valen más cuando aplican uniformemente al portafolio; pesan menos las que solo benefician a un repo aislado.
3. **Fricción mínima viable para devs** — cada práctica debe justificar su costo cognitivo/operativo en cada PR. Baseline ligero por defecto; endurecer donde el riesgo lo justifique.
4. **Adaptación al flujo IA** — el cálculo de valor de cada práctica considera explícitamente que parte sustancial del código viene de IA: la revisión humana, el scanning automático y los guardrails de paths/secretos suben su valor; las prácticas que solo reducen ruido humano (templates ornamentales) bajan.

## Opciones consideradas — modelo operativo de gobernanza

- **A. Laissez-faire**: cada repositorio hace lo que considere; sin política formal a nivel de organización. Es el estado actual; los hallazgos de auditoría son consecuencia directa. Cero fricción para los devs; ninguna mitigación de riesgos sistémicos.

- **B. Descentralizada por equipo/dominio**: cada equipo o dominio define sus políticas para sus repos, sin estándar a nivel organización. Respeta el contexto local de cada dominio; produce inconsistencia entre repos, descubribilidad nula (cada repo se comporta distinto) y duplicación de esfuerzo. Requiere madurez de gobierno por equipo que no necesariamente está presente uniformemente.

- **C. Centralizada estricta uniforme**: una política única igual para todos los repos del portafolio, sin distinción de criticidad. Máxima consistencia y simplicidad mental ("toda regla aplica a todo"). Ignora que un POC, una librería interna y un servicio de cara al cliente tienen necesidades distintas; produce fricción innecesaria en repos donde el riesgo es bajo; tiende a generar pushback de equipos.

- **D. Híbrida org-wide con segmentación por custom properties**: un baseline universal mínimo se fuerza a nivel organización vía Rulesets (cubre los riesgos de mayor impacto y costo bajo de mitigar). Las capas adicionales se aplican selectivamente vía custom properties (p. ej. tier de criticidad, stack, dominio). Las plantillas comunes (community health files, dependabot, PR template, CODEOWNERS base) viven en `Cosmos-SincoERP/.github` y aplican org-wide a repos que no tengan las suyas. Toma la consistencia de C y le agrega segmentación inteligente cuando se necesite. Requiere que se decida qué propiedades y valores existirán (eso se hace en [[0002]] o [[0003]]).

- **E. Diferir hasta upgrade a Enterprise + GHAS**: postergar el grueso de la gobernanza hasta el upgrade a GitHub Enterprise con Advanced Security, que habilitaría required workflows org-wide, push protection en repos privados, CodeQL en privados y SAML/SSO. Lo que se construya en ese momento sería más robusto y forzable, pero deja una ventana de exposición con la línea base actual (2FA off, base permission admin, Actions sin restricción).

## Decisión

Se adopta el **modelo D — Híbrida org-wide con segmentación por custom properties**:

- Un **baseline universal mínimo** se fuerza a nivel organización vía Rulesets, cubriendo los riesgos de mayor impacto y costo bajo de mitigar.
- Las **capas adicionales** se aplican selectivamente vía custom properties (criticidad, stack, dominio u otras a definir cuando se necesite).
- Las **plantillas comunes** (community health files, dependabot, PR template, CODEOWNERS base) viven en `Cosmos-SincoERP/.github` y aplican org-wide a repos que no tengan las suyas.

**Valores específicos de custom properties** (qué propiedades existen, qué valores admiten, cómo se clasifica el portafolio) **se postergan**: no se definen en este ADR. Se decidirán en [[0003]] cuando exista producción y la diferenciación por tier sea funcionalmente necesaria, o en un ADR posterior si surge antes una necesidad distinta. Mientras tanto, [[0002]] aplica baseline único sin segmentación.

## Niveles de decisión y de aplicación

Vocabulario que se utiliza en [[0002]] y [[0003]] para decidir cada práctica del catálogo.

**Niveles de decisión por práctica**:
- **Aplicar (org)**: se fuerza desde la organización (vía Ruleset, configuración de org, plantilla en `.github`).
- **Aplicar (repo)**: se documenta como obligatorio por repo, pero no se puede forzar centralmente; cada repo debe replicar la configuración.
- **Diferir**: no se aplica ahora; se reevalúa en un momento posterior o cuando se cumpla una condición específica.
- **Descartar**: explícitamente no se adopta, con razón documentada.

**Fases de aplicación temporal**:
- **Fase 0**: crítico, aplicar lo antes posible (días). Prácticas cuyo no-cumplimiento expone la organización a riesgos graves y baratos de mitigar.
- **Fase 1**: rollout estándar (semanas). Conjunto de políticas que conforma el baseline de gobernanza dev.
- **Fase 2**: cuando exista ambiente de producción. Capas adicionales aplicables cuando el modelo operativo lo amerite.

## Principios rectores

- **Lo que se pueda forzar org-wide va org-wide.** Replicar configuración manualmente en 49 repos es insostenible; preferir Rulesets sobre branch protection clásico; preferir plantillas en `Cosmos-SincoERP/.github` sobre instrucciones por repo.
- **Documentar lo descartado, no solo lo aceptado.** Cada práctica del catálogo termina con una decisión registrada y justificada en [[0002]] o [[0003]] (incluso si la decisión es "no aplicar" o "diferir"). Evita re-litigar la misma discusión en seis meses.

## Catálogo de prácticas candidatas

Cada práctica se describe con los siguientes campos sin recomendación ni decisión:
- **Qué es**: descripción breve.
- **Para qué**: problema que resuelve o riesgo que mitiga.
- **Cómo en GitHub**: ruta UI y/o comando API/`gh`.
- **Disponibilidad Team**: si es viable bajo el plan actual y, si no, qué requiere.
- **Consideración bajo flujo IA**: cómo cambia su valor cuando una porción del código viene de IA.

---

### Categoría A — Identidad y permisos de la organización

#### A.1 — 2FA obligatorio en la organización
- **Qué es**: requerir que todo miembro y outside collaborator de la org tenga autenticación de dos factores habilitada.
- **Para qué**: protege contra compromiso de cuentas y takeover; reduce drásticamente el riesgo de que credenciales filtradas se traduzcan en acceso al código.
- **Cómo en GitHub**: Settings → Authentication security → Require two-factor authentication. `gh api -X PATCH orgs/Cosmos-SincoERP -f two_factor_requirement_enabled=true`. Los miembros que no cumplan son removidos de la org (con notificación previa).
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: alta. Las cuentas humanas son la frontera de confianza última cuando agentes IA actúan en su nombre; 2FA limita el blast radius de un compromiso.

#### A.2 — `default_repository_permission` por defecto
- **Qué es**: permiso base que cualquier miembro de la organización tiene sobre cualquier repo no explícitamente restringido. Valores posibles: `none`, `read`, `write`, `admin`.
- **Para qué**: limita la superficie de cambio accidental o malicioso; concentra el otorgamiento de permisos en teams y CODEOWNERS en vez de membership.
- **Cómo en GitHub**: Settings → Member privileges → Base permissions. `gh api -X PATCH orgs/Cosmos-SincoERP -f default_repository_permission=read|write|none`.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: alta. Si miembros y agentes operan con `admin` por defecto, un solo error de IA puede modificar settings o forzar push en cualquier repo; `read` o `none` obliga a otorgar permisos deliberadamente.

#### A.3 — Política de creación de repositorios
- **Qué es**: control sobre quién puede crear repos públicos, privados o internos en la organización.
- **Para qué**: previene proliferación de repos sin gobierno; permite forzar que la creación pase por un proceso (request, plantilla, clasificación).
- **Cómo en GitHub**: Settings → Member privileges → Repository creation. Toggles `members_can_create_public_repositories`, `members_can_create_private_repositories`, `members_can_create_internal_repositories`.
- **Disponibilidad Team**: ✅ disponible (`internal` no aplica en Team, solo Enterprise).
- **Consideración bajo flujo IA**: media. Reduce la creación accidental de repos por scripts o agentes; obliga a que un humano pase por el flujo de creación.

#### A.4 — Política de outside collaborators
- **Qué es**: si se permiten outside collaborators (cuentas que no son miembros de la org pero tienen acceso a repos específicos) y bajo qué condiciones (fork de privados, etc.).
- **Para qué**: limita el acceso de cuentas externas (consultores, contratistas, automatización de terceros) y obliga a revisión periódica.
- **Cómo en GitHub**: Settings → Member privileges → fork policy, plus governance manual (auditoría periódica de la lista de outside collaborators).
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: media-baja. Más relevante si se usan agentes externos con cuentas dedicadas.

#### A.5 — Security managers
- **Qué es**: rol que permite a un team gestionar las políticas de seguridad y configuraciones de seguridad a través de todos los repos de la org, sin necesidad de ser admin.
- **Para qué**: separa preocupaciones de seguridad de administración general; permite que un equipo de seguridad tenga vista y acción transversal sin sobre-privilegio.
- **Cómo en GitHub**: Settings → Security → Security managers. `gh api -X PUT orgs/Cosmos-SincoERP/security-managers/teams/<team>`.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: media. Útil para que un team con foco en seguridad valide periódicamente las configuraciones generadas o sugeridas por agentes.

---

### Categoría B — Protección de ramas y Rulesets

#### B.1 — Require pull request before merging (en default branch)
- **Qué es**: prohibir push directo al default branch (`main`); todo cambio debe pasar por PR.
- **Para qué**: garantiza un punto de revisión y registro auditable de cambios; bloquea push accidental con `git push main`.
- **Cómo en GitHub**: Rulesets org-level con regla `pull_request`. UI: Settings → Rules → New ruleset → Branch ruleset → Target default branch → Add rule "Require a pull request before merging".
- **Disponibilidad Team**: ✅ disponible (Rulesets a nivel org).
- **Consideración bajo flujo IA**: alta. Agentes IA pueden tener tokens con write directo; sin esta regla, un agente podría push-ear directo a `main` sin revisión.

#### B.2 — Require N approvals (1, 2, 3)
- **Qué es**: número mínimo de aprobaciones de PR antes de poder mergear. Valores comunes: 1, 2.
- **Para qué**: asegura revisión humana; 2 aprobaciones reducen el riesgo de un solo aprobador colusionado o distraído.
- **Cómo en GitHub**: regla `pull_request` en Ruleset, parámetro `required_approving_review_count`.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: alta. Cuando el autor del PR es un agente IA, la revisión humana es la última línea de defensa. 2 aprobaciones añaden fricción significativa en dev pero pueden justificarse en repos críticos.

#### B.3 — Dismiss stale pull request approvals when new commits are pushed
- **Qué es**: invalidar aprobaciones previas si el autor pushea nuevos commits después de la aprobación.
- **Para qué**: previene que cambios añadidos post-revisión entren sin re-revisión.
- **Cómo en GitHub**: parámetro `dismiss_stale_reviews_on_push` en la regla `pull_request`.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: muy alta. Es común que después de una primera aprobación, autor o agente añada "un último fix" que cambia significativamente el diff. Sin dismiss, esos cambios entran sin revisión.

#### B.4 — Require review from CODEOWNERS
- **Qué es**: requerir que los archivos modificados en el PR sean aprobados por los owners declarados en `CODEOWNERS`.
- **Para qué**: enruta automáticamente la revisión al experto del dominio; evita merges sin que el dueño del código vea el cambio.
- **Cómo en GitHub**: parámetro `require_code_owner_review` en la regla `pull_request`. Requiere `CODEOWNERS` en el repo (en `.github/`, root o `docs/`).
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: alta. Cuando IA toca múltiples partes de un sistema, CODEOWNERS asegura que cada dominio sea revisado por su experto humano, no solo por un aprobador general.

#### B.5 — Require conversation resolution before merging
- **Qué es**: bloquear el merge hasta que todos los hilos de comentarios del PR estén marcados como resueltos.
- **Para qué**: garantiza que las observaciones de los revisores no quedan sin atender; evita el patrón de "aprobaron pero ignoraron mi comentario".
- **Cómo en GitHub**: regla `required_review_thread_resolution` en Ruleset.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: alta. Los comentarios suelen ser puntos de matiz que la IA podría no haber considerado; resolverlos forza un ack explícito.

#### B.6 — Require signed commits
- **Qué es**: exigir que todos los commits del PR estén firmados criptográficamente (GPG, SSH o S/MIME), o sean firmados por GitHub (web edits).
- **Para qué**: garantiza autoría verificable de cada commit; previene impersonation y manipulación del historial.
- **Cómo en GitHub**: regla `required_signatures` en Ruleset.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: media. Aumenta confianza en la cadena de autoría pero introduce fricción setup (configurar GPG/SSH commit signing en cada máquina y agente). Para agentes IA con tokens, requiere configurar firma en su entorno.

#### B.7 — Require linear history
- **Qué es**: prohibir merge commits en el default branch; todos los merges deben ser fast-forward (squash o rebase).
- **Para qué**: historial limpio, lineal, fácil de bisect; evita la "merge commits soup".
- **Cómo en GitHub**: regla `required_linear_history` en Ruleset.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: media. Facilita revertir cambios generados por IA (1 commit = 1 cambio lógico). Compatible con squash-only.

#### B.8 — Block force push
- **Qué es**: prohibir `git push --force` o `git push --force-with-lease` al default branch.
- **Para qué**: protege el historial; un force push puede sobrescribir commits válidos y romper el trabajo de otros.
- **Cómo en GitHub**: regla `non_fast_forward` en Ruleset (block en valor `true`).
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: muy alta. Si un agente IA tiene write y comete un error, un force-push puede destruir trabajo no recuperable; bloquearlo es trivial y barato.

#### B.9 — Block branch deletion
- **Qué es**: prohibir borrar el default branch (o cualquiera que matchee el ruleset).
- **Para qué**: previene la pérdida accidental del branch principal de un repo.
- **Cómo en GitHub**: regla `deletion` en Ruleset (block).
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: alta. Bajo costo, evita catástrofes.

#### B.10 — Restrict who can push to matching branches
- **Qué es**: lista de actores (users, teams, GitHub Apps) autorizados a hacer push (incluido el merge de PRs) en las ramas del ruleset.
- **Para qué**: limita quién puede ejecutar merges; útil para gates de releases o ramas sensibles.
- **Cómo en GitHub**: regla `restrict_pushes` en Ruleset con `actor_id` y `actor_type`.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: alta para producción. En dev puede ser excesivo; en repos críticos limita el conjunto de actores autorizados a empujar.

#### B.11 — Tag protection rules
- **Qué es**: protección de tags que matchean un patrón (p. ej. `v*`, `release-*`) — bloquear creación, borrado o sobrescritura por actores no autorizados.
- **Para qué**: garantiza que los tags de release son inmutables y solo los crea el flujo autorizado (workflow de release, persona específica).
- **Cómo en GitHub**: Tag ruleset con reglas `creation`, `deletion`, `update`.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: alta para producción. Los tags identifican releases; manipulación maliciosa o accidental puede romper deploy pipelines o crear confusión.

#### B.12 — Push rulesets (paths, extensiones, tamaño)
- **Qué es**: reglas que validan el contenido de un push antes de aceptarlo: bloquear paths específicos (p. ej. `.env*`, `*.pem`), bloquear extensiones, limitar tamaño de archivo, requerir convención de mensaje de commit.
- **Para qué**: previene commit accidental de secretos, binarios grandes o archivos sensibles.
- **Cómo en GitHub**: Push ruleset (org-level) con `file_path_restriction`, `file_extension_restriction`, `max_file_size`, `commit_message_pattern`.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: muy alta. Los agentes IA pueden, por error, commitear archivos sensibles que generaron o que el contexto les dio (claves, dumps). Es un guardrail barato y efectivo.

#### B.13 — Default branch name uniforme (`main`)
- **Qué es**: estandarizar que todos los repos usen `main` como default branch (o el nombre que se decida).
- **Para qué**: predictibilidad para scripts, automatizaciones, plantillas y documentación.
- **Cómo en GitHub**: Settings → Repository → Repository default branch (org-wide). Aplica a repos nuevos; los existentes se renombran individualmente.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: media. Los agentes a menudo asumen `main`; tener excepciones (la auditoría encontró `Cosmos.Terceros` con `feature/dominio` como default) rompe automatizaciones.

#### B.14 — Mecanismo de targeting por custom properties
- **Qué es**: capacidad de Rulesets de aplicarse selectivamente a repos que matcheen valores de custom properties (p. ej. `repo-tier=critical`).
- **Para qué**: habilita el modelo híbrido (opción D del marco) sin proliferar Rulesets ni listas manuales.
- **Cómo en GitHub**: definir custom properties org-wide (`gh api -X PATCH orgs/<org>/properties/schema`), asignar valores a repos (`gh api -X PATCH orgs/<org>/properties/values`), usar `conditions.repository_property` en Rulesets.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: alta. Permite que las políticas más estrictas se concentren donde más importa (repos críticos) sin uniformar a costa de fricción.

---

### Categoría C — PRs, revisión y CODEOWNERS

#### C.1 — Pull request template
- **Qué es**: archivo `.github/PULL_REQUEST_TEMPLATE.md` (o variantes múltiples en `.github/PULL_REQUEST_TEMPLATE/`) que rellena el cuerpo del PR al crearse.
- **Para qué**: estandariza la información que se espera del autor (qué cambió, por qué, cómo probar, riesgos).
- **Cómo en GitHub**: commit en el repo o vivir en `Cosmos-SincoERP/.github` para defaults org-wide. Markdown puro.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: alta y de doble filo. La IA puede rellenarlo trivialmente (baja costo cognitivo), lo que hace fácil que se vuelva ruido auto-generado. Si se adopta, el template debe pedir información que la IA no pueda inventar (test plan ejecutado, decisiones tomadas).

#### C.2 — Issue templates
- **Qué es**: plantillas para creación de issues (`.github/ISSUE_TEMPLATE/*.md` o `.yml`).
- **Para qué**: estructura los reportes de bugs y solicitudes; reduce ida y vuelta para clarificar.
- **Cómo en GitHub**: archivos en el repo o en `Cosmos-SincoERP/.github` para defaults org-wide. Formato YAML moderno permite forms con campos validados.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: baja-media. Más útil para entrada humana; agentes IA tienden a no usar issues como punto de entrada.

#### C.3 — CODEOWNERS por dominio/servicio
- **Qué es**: archivo `CODEOWNERS` que mapea paths (globs) a usuarios o teams responsables de aprobar cambios en esos paths.
- **Para qué**: enruta la revisión automáticamente; documenta de facto el ownership del código.
- **Cómo en GitHub**: archivo `CODEOWNERS` en `.github/`, root o `docs/` del repo. Sintaxis: `*.ts @cosmos/team-frontend`.
- **Disponibilidad Team**: ✅ disponible. Funciona en conjunto con B.4 (require CODEOWNERS review).
- **Consideración bajo flujo IA**: muy alta. Como la IA toca muchos archivos cruzados, CODEOWNERS evita que un solo aprobador "general" apruebe cambios en dominios de los que no es experto.

#### C.4 — Auto-merge habilitado
- **Qué es**: capacidad de marcar un PR para que se mergee automáticamente cuando se cumplan todos los requisitos (approvals, status checks, conversation resolution).
- **Para qué**: reduce latencia entre "todo listo" y merge; útil para PRs de Dependabot o que esperan checks largos.
- **Cómo en GitHub**: Settings → General → "Allow auto-merge". Por PR: botón "Enable auto-merge".
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: media. Combinado con aprobaciones estrictas, es seguro; sin ellas, riesgoso (PR generado por IA + auto-merge + aprobador laxo = merge sin revisión real).

#### C.5 — Política de merge (squash, merge commit, rebase)
- **Qué es**: qué estrategias de merge están habilitadas en los repos. Opciones: squash-only, merge-commit-only, rebase-only, o cualquier combinación.
- **Para qué**: define la forma del historial. Squash-only produce historia lineal con 1 commit por PR; merge-commit preserva el historial del branch; rebase combina ambos.
- **Cómo en GitHub**: Settings → General → Pull Requests → "Allow merge commits / squash merging / rebase merging". A nivel org no se puede forzar directamente (cada repo decide), pero se puede setear por API en bootstrap.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: alta. Squash-only simplifica revertir cambios generados por IA (un PR = un commit = un revert). La historia interna del branch (con commits "fix", "wip", "más fix") se pierde, pero esa pérdida suele ser deseable.

#### C.6 — Auto-delete branch on merge
- **Qué es**: borrar automáticamente la rama del PR después de mergear.
- **Para qué**: higiene; evita acumulación de cientos de ramas obsoletas.
- **Cómo en GitHub**: Settings → General → "Automatically delete head branches". Por repo; org-level setting no existe (se aplica en bootstrap).
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: media. Los agentes pueden crear muchas ramas; auto-delete mantiene el repo navegable.

#### C.7 — Convención de títulos / conventional commits
- **Qué es**: estandarizar el formato del título de PR / commit (p. ej. `feat: ...`, `fix(scope): ...`).
- **Para qué**: habilita changelog automatizado (semantic-release, release-please), facilita lectura del historial.
- **Cómo en GitHub**: regla `commit_message_pattern` en push ruleset para PRs con squash-only (el mensaje del squash hereda del título); o validación en CI vía action.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: alta. La IA puede aprender y aplicar el formato trivialmente; usar la convención permite extraer changelog sin trabajo humano adicional.

#### C.8 — Draft PRs como convención
- **Qué es**: usar "Draft PR" en GitHub para señalizar trabajo en curso que no debe ser revisado todavía.
- **Para qué**: separa señales: "esto está listo para revisión" vs "esto es contexto/avance".
- **Cómo en GitHub**: feature nativa de GitHub. Convención de equipo, no configurable como regla.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: media. Útil cuando un agente itera; abrir como draft, marcarlo "ready for review" solo cuando está terminado.

#### C.9 — Labels estándar org-wide
- **Qué es**: conjunto canónico de labels (tipo: `bug`, `feature`, `chore`; impacto: `breaking`, `dependencies`; estado: `blocked`, `wip`) replicado en todos los repos.
- **Para qué**: facilita filtrado y reporting cross-repo; consistencia visual.
- **Cómo en GitHub**: org settings no permite definir labels org-wide; se replican via script o GitHub Action (`crazy-max/ghaction-github-labeler` u otros).
- **Disponibilidad Team**: ✅ disponible (con automatización).
- **Consideración bajo flujo IA**: baja-media. Útil para clasificar PRs masivos generados por agentes.

---

### Categoría D — CI/CD y checks requeridos

#### D.1 — Status checks obligatorios
- **Qué es**: marcar status checks específicos (jobs de CI: build, lint, test, scan) como bloqueantes del merge.
- **Para qué**: garantiza que solo código que pasa el pipeline llega al default branch.
- **Cómo en GitHub**: regla `required_status_checks` en Ruleset, con lista de check names (deben coincidir con `jobs.<name>.name` o el `name:` del workflow).
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: muy alta. Los tests automáticos son la barrera de calidad más confiable cuando la IA genera código que un humano podría no entender a fondo.

#### D.2 — Environments con required reviewers
- **Qué es**: definir environments (`staging`, `production`) con lista de aprobadores requeridos antes de que un workflow pueda desplegar a ellos.
- **Para qué**: gate humano entre la generación del artefacto y el despliegue; típicamente reservado para producción.
- **Cómo en GitHub**: Settings → Environments → New environment → Add required reviewers.
- **Disponibilidad Team**: ✅ disponible (con limitaciones: en repos privados Team, los environments con required reviewers requieren plan Pro o superior — verificar al implementar).
- **Consideración bajo flujo IA**: muy alta para producción. Es el punto donde un humano dice "sí, este código va a impactar usuarios reales".

#### D.3 — Pinning de acciones (SHA vs tag/branch)
- **Qué es**: pinnear acciones en workflows por SHA inmutable (`actions/checkout@a12s3...`) en vez de tag móvil (`actions/checkout@v4`) o branch.
- **Para qué**: protección contra supply chain attacks (un tag puede ser reasignado a un commit malicioso); reproducibilidad.
- **Cómo en GitHub**: edición manual o tooling (`tj-actions/get-changed-files` analyzers, dependabot puede actualizar pinning por SHA).
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: alta para terceros, media para internos. Para reusables internos de `Cosmos.PlatformWorkflows`, el control está dentro del perímetro (`@v1` interno puede ser aceptable); para acciones de terceros, SHA pinning protege contra compromiso upstream.

#### D.4 — `permissions:` mínimo en `GITHUB_TOKEN`
- **Qué es**: declarar explícitamente los permisos del token de cada workflow al mínimo necesario (default `contents: read`, escalando solo cuando se requiere).
- **Para qué**: limita el blast radius de un workflow comprometido o vulnerable a injection.
- **Cómo en GitHub**: bloque `permissions:` a nivel de workflow o job. A nivel org: Settings → Actions → Workflow permissions → "Read repository contents and packages permissions" (default).
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: alta. Los workflows generados por IA pueden inadvertidamente otorgar permisos amplios; setting org-wide a `read` por defecto fuerza la opt-in explícita.

#### D.5 — Allowed Actions a nivel organización (allowlist)
- **Qué es**: restringir qué acciones de terceros pueden ser usadas en workflows org-wide. Opciones: todas, solo locales, solo creadores verificados, o lista explícita.
- **Para qué**: previene el uso de acciones desconocidas o no auditadas; reduce superficie supply chain.
- **Cómo en GitHub**: Settings → Actions → General → "Allow specified actions and reusable workflows". `gh api -X PUT orgs/<org>/actions/permissions -F enabled_repositories=all -F allowed_actions=selected`.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: muy alta. Es la principal barrera contra agentes IA que añaden acciones de terceros que "encontraron en un ejemplo"; con allowlist, el agente solo puede usar lo permitido.

#### D.6 — Secrets y variables a nivel organización (con scoping por repo)
- **Qué es**: definir secretos y variables a nivel org y limitar a qué repos son visibles (all, private only, selected).
- **Para qué**: evita duplicar secretos en cada repo; centraliza rotación; scoping limita la exposición.
- **Cómo en GitHub**: Settings → Secrets and variables → Actions → New organization secret/variable, con `visibility` y `selected_repository_ids`.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: alta. Rotación centralizada importa más cuando muchas pipelines (algunas generadas por agentes) las consumen. Scoping por repo evita que un agente en un repo bajo riesgo lea secretos de un repo crítico.

#### D.7 — Reusable workflows centralizados
- **Qué es**: workflows definidos con `workflow_call` que otros workflows en otros repos invocan vía `uses: org/repo/.github/workflows/file.yml@ref`.
- **Para qué**: DRY entre repos; un cambio en el reusable se propaga a todos los consumidores; reduce drift.
- **Cómo en GitHub**: archivos en `.github/workflows/` de un repo (en Cosmos, `Cosmos.PlatformWorkflows`) con `on: workflow_call:`. Consumidores: `uses: Cosmos-SincoERP/Cosmos.PlatformWorkflows/.github/workflows/_reusable-tests-dotnet.yml@v1`.
- **Disponibilidad Team**: ✅ disponible. **Ya implementado** en `Cosmos.PlatformWorkflows` (8 reusables: tests-dotnet, tests-frontend, docker-build-push, deploy-swarm, deploy-front, bump-and-tag, nuget-publish, cleanup-acr-pr).
- **Consideración bajo flujo IA**: alta. Los agentes pueden invocar reusables ya bendecidos en vez de generar workflows desde cero; reduce variabilidad y riesgo.

#### D.8 — Concurrency control en workflows
- **Qué es**: bloque `concurrency:` que asegura que solo un workflow de un grupo corre a la vez (cancelando los anteriores o esperándolos).
- **Para qué**: evita carreras (p. ej. dos deploys al mismo environment simultáneos); ahorra runner-minutes cancelando pipelines obsoletos.
- **Cómo en GitHub**: bloque `concurrency: group: <key> cancel-in-progress: true|false` a nivel de workflow.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: media. Útil cuando agentes pueden disparar muchas runs (p. ej. PRs masivos); cancel-in-progress mantiene costos controlados.

#### D.9 — OIDC para deploys (en vez de secretos long-lived)
- **Qué es**: federation OpenID Connect entre GitHub Actions y el cloud (Azure, AWS, GCP) para que el workflow obtenga credenciales temporales sin tener un secreto persistente almacenado.
- **Para qué**: elimina secretos long-lived (que se filtran o rotan mal); reduce blast radius si el repo es comprometido.
- **Cómo en GitHub**: GitHub Action de auth del provider (`azure/login@v2` con `auth-type: identity`, `aws-actions/configure-aws-credentials@v4` con `role-to-assume`), más configuración del lado del cloud (workload identity federation en Azure, OIDC provider + role trust policy en AWS).
- **Disponibilidad Team**: ✅ disponible. **Ya implementado parcialmente** en `Cosmos.PlatformWorkflows` vía Azure Managed Identity en runners self-hosted.
- **Consideración bajo flujo IA**: muy alta. Reduce el conjunto de secretos que un agente comprometido podría exfiltrar.

#### D.10 — Required workflows org-wide
- **Qué es**: forzar a nivel organización que ciertos workflows se ejecuten en todos los repos (o subconjuntos), como check requerido independiente del repo.
- **Para qué**: estandariza scans, compliance checks o validaciones obligatorias sin depender de que cada repo los añada.
- **Cómo en GitHub**: Settings → Actions → General → "Required workflows" (en orgs Enterprise).
- **Disponibilidad Team**: ❌ **No disponible** (requiere GitHub Enterprise Cloud). Workaround: status checks bloqueantes en Rulesets + plantilla de workflow commiteada vía script de bootstrap a cada repo.
- **Consideración bajo flujo IA**: alta. Si estuviera disponible, sería el mecanismo ideal para garantizar que un scan corre en todo PR sin importar quién (o qué agente) creó el repo o el workflow.

---

### Categoría E — Seguridad y dependencias

#### E.1 — Dependabot alerts
- **Qué es**: GitHub escanea las dependencias declaradas (package.json, *.csproj, Pipfile, etc.) contra la GitHub Advisory Database y reporta vulnerabilidades conocidas.
- **Para qué**: visibilidad temprana de CVE en dependencias directas y transitivas.
- **Cómo en GitHub**: Settings → Code security and analysis → Dependabot alerts. Org-wide: Settings org → Code security → Configure.
- **Disponibilidad Team**: ✅ disponible (también en repos privados).
- **Consideración bajo flujo IA**: media-alta. La IA puede introducir dependencias sin validar su CVE history; Dependabot ataja eso post-hoc.

#### E.2 — Dependabot security updates
- **Qué es**: cuando Dependabot detecta una vulnerabilidad, abre PRs automáticos que actualizan la dependencia a una versión sin CVE.
- **Para qué**: cierre del loop entre detección y fix; reduce mean-time-to-patch.
- **Cómo en GitHub**: Settings → Code security → Dependabot security updates. Org-wide enable.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: alta. Los PRs auto-generados pueden mergearse con auto-merge si pasan los checks, reduciendo carga humana.

#### E.3 — Dependabot version updates (`.github/dependabot.yml`)
- **Qué es**: configuración explícita por repo (`.github/dependabot.yml`) que define qué ecosistemas y con qué cadencia se abren PRs de actualización (incluso sin CVE).
- **Para qué**: mantiene dependencias al día proactivamente; reduce deuda de actualización.
- **Cómo en GitHub**: archivo YAML por repo. Plantilla en `Cosmos-SincoERP/.github` puede actuar como default (los repos sin el suyo propio lo heredan, según docs de GitHub para community health files).
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: alta. Volumen alto de PRs de bumps que la IA puede ayudar a revisar/agrupar; squash + auto-merge + tests verdes mantiene los repos al día con poco overhead.

#### E.4 — Dependency review action en PRs
- **Qué es**: GitHub Action (`actions/dependency-review-action@v4`) que en cada PR compara el lock file antes/después y bloquea si se introducen dependencias con vulnerabilidades, licencias prohibidas o de fuentes no permitidas.
- **Para qué**: feedback inmediato en el PR (no post-merge); previene merge de dependencias problemáticas.
- **Cómo en GitHub**: workflow en `.github/workflows/dependency-review.yml`. Puede vivir como reusable en `Cosmos.PlatformWorkflows`.
- **Disponibilidad Team**: ✅ disponible (gratis para repos públicos; para privados requiere GHAS).
- **Consideración bajo flujo IA**: muy alta. La IA puede agregar dependencias sin revisar licencia o CVE; este check lo bloquea en la puerta de entrada.

#### E.5 — Secret scanning (repos públicos, gratis)
- **Qué es**: GitHub escanea el contenido de los repos públicos contra patrones conocidos de secretos (API keys, tokens) y alerta a partners (AWS, Azure, etc.) para revocación automática.
- **Para qué**: detección y mitigación de secretos accidentalmente publicados.
- **Cómo en GitHub**: Settings → Code security → Secret scanning. **Activo por defecto en repos públicos**, no requiere configuración.
- **Disponibilidad Team**: ✅ disponible **solo para repos públicos**.
- **Consideración bajo flujo IA**: alta. La IA puede pegar inadvertidamente claves del contexto; en repos públicos, GitHub las detecta.

#### E.6 — Secret scanning + push protection en repos privados (GHAS)
- **Qué es**: extensión de E.5 a repos privados, incluyendo **push protection** (bloquear el push si contiene un secret pattern).
- **Para qué**: previene que el secret entre al repo en primer lugar (no solo detectar post-commit).
- **Cómo en GitHub**: Settings → Code security → Secret scanning + push protection. Requiere licencia GHAS.
- **Disponibilidad Team**: ❌ **No disponible** en repos privados (requiere GitHub Enterprise + GHAS). Mitigaciones open-source: `gitleaks` o `trufflehog` corridos en CI; pre-commit hooks; push rulesets (B.12) que bloquean paths `.env*`, `*.pem`.
- **Consideración bajo flujo IA**: muy alta. Los agentes pueden generar y commitear secretos accidentalmente; sin GHAS, hay que cubrirlo con mitigaciones.

#### E.7 — Code scanning / CodeQL
- **Qué es**: análisis estático de código contra patrones de vulnerabilidades (SQL injection, XSS, path traversal, etc.) usando CodeQL u otras herramientas (ESLint, Bandit, etc.) que reportan al GitHub Security tab.
- **Para qué**: detectar vulnerabilidades de código antes de producción.
- **Cómo en GitHub**: workflow CodeQL en `.github/workflows/codeql.yml`. Gratis para repos públicos; en privados requiere GHAS.
- **Disponibilidad Team**: ✅ en repos públicos. ❌ CodeQL nativo en privados (GHAS). Mitigaciones open-source: análisis local (Roslyn analyzers para C#, ESLint para JS/TS), Semgrep OSS rules en CI.
- **Consideración bajo flujo IA**: alta. La IA puede generar código vulnerable a patrones conocidos (XSS, injection); el scan ataja antes de prod.

#### E.8 — Private vulnerability reporting
- **Qué es**: canal privado para que terceros reporten vulnerabilidades a los maintainers del repo sin disclosure público inmediato.
- **Para qué**: investigadores externos pueden alertar sin tener que publicarlo.
- **Cómo en GitHub**: Settings → Code security → Private vulnerability reporting. Org-wide enable.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: baja (no cambia con IA). Higiene de seguridad estándar.

#### E.9 — `SECURITY.md`
- **Qué es**: archivo en root, `.github/` o `docs/` que documenta canal de reporte de vulnerabilidades, versiones soportadas, política de respuesta.
- **Para qué**: comunica externamente cómo reportar issues de seguridad; GitHub linkea automáticamente desde la pestaña Security.
- **Cómo en GitHub**: archivo Markdown. Default org-wide vivo en `Cosmos-SincoERP/.github`.
- **Disponibilidad Team**: ✅ disponible.
- **Consideración bajo flujo IA**: baja. Comunicación humana.

#### E.10 — SBOM exports (Software Bill of Materials)
- **Qué es**: exportar un manifiesto de dependencias del proyecto en formato SPDX o CycloneDX.
- **Para qué**: trazabilidad de qué componentes (y sus versiones) integran el producto; útil para auditoría, respuesta a CVE (¿estoy afectado?), compliance.
- **Cómo en GitHub**: GitHub Dependency Graph genera SBOM nativo (`gh api repos/<owner>/<repo>/dependency-graph/sbom`); alternativa: action `CycloneDX/gh-dotnet-generate-sbom` u otras por stack.
- **Disponibilidad Team**: ✅ disponible (export nativo).
- **Consideración bajo flujo IA**: media. Cuando la IA introduce dependencias, el SBOM materializa qué entró y desde cuándo.

#### E.11 — SSO / SAML
- **Qué es**: integración con identity provider corporativo (Azure AD/Entra, Okta, etc.) para autenticación de miembros de la org.
- **Para qué**: control centralizado de acceso (alta/baja desde el IdP), policies de identidad corporativas, auditoría unificada.
- **Cómo en GitHub**: Settings → Authentication security → SAML SSO.
- **Disponibilidad Team**: ❌ **No disponible** (requiere GitHub Enterprise Cloud).
- **Consideración bajo flujo IA**: alta para producción. Centraliza la baja de cuentas (cuando alguien sale de la empresa) sin depender de revocar manualmente en GitHub.

---

## Mapa de decisiones por fase

| Práctica | Decisión | Nivel | Fase | ADR |
|---|---|---|---|---|
| A.1 — 2FA obligatorio | Aplicar | org | 0 | [[0002]] |
| A.2 — Base permission | Aplicar (transición: grandfather actuales como admin, nuevos = `write`) | org | 1 | [[0002]] |
| A.3 — Creación de repos | Diferir (no expresable en Team — reevaluar con Enterprise) | — | 2 | [[0003]] |
| A.4 — Outside collaborators | Aplicar (prohibidos por default, excepción documentada) | org | 1 | [[0002]] |
| A.5 — Security managers | Aplicar (asignar team plataforma) | org | 1 | [[0002]] |
| B.1 — Require PR | Aplicar | org | 0 | [[0002]] |
| B.2 — N approvals | Aplicar (0 approvals — require PR solamente) | org | 1 | [[0002]] |
| B.3 — Dismiss stale approvals | Aplicar | org | 1 | [[0002]] |
| B.4 — CODEOWNERS review (regla activa) | Aplicar (sin forzar tener CODEOWNERS) | org | 1 | [[0002]] |
| B.5 — Conversation resolution | Aplicar | org | 1 | [[0002]] |
| B.6 — Signed commits | Diferir | — | 2 | [[0003]] |
| B.7 — Linear history | Aplicar | org | 1 | [[0002]] |
| B.8 — Block force push | Aplicar | org | 1 | [[0002]] |
| B.9 — Block deletion | Aplicar | org | 1 | [[0002]] |
| B.10 — Restrict who can push | No aplicar en dev (decisión explícita) | — | — | [[0002]] |
| B.11 — Tag protection | Diferir | — | 2 | [[0003]] |
| B.12 — Push rulesets (paths/tamaño) | Aplicar (set estricto) | org | 0 | [[0002]] |
| B.13 — Default branch `main` | Aplicar + remediar excepciones | org | 1 | [[0002]] |
| B.14 — Targeting por custom properties | Mecanismo adoptado (heredado de modelo D); valores diferidos | org | — | [[0003]] |
| C.1 — PR template | Descartar | — | — | [[0002]] |
| C.2 — Issue templates | Descartar | — | — | [[0002]] |
| C.3 — CODEOWNERS por dominio | Aplicar solo a nivel repo (sin default org-wide) | repo | 1 | [[0002]] |
| C.4 — Auto-merge | Aplicar | repo (org-wide) | 1 | [[0002]] |
| C.5 — Política de merge | Aplicar (squash-only) | repo (org-wide) | 1 | [[0002]] |
| C.6 — Auto-delete branch | Aplicar | repo (org-wide) | 1 | [[0002]] |
| C.7 — Convención de títulos | Diferir | — | — | [[0002]] |
| C.8 — Draft PRs como convención | Descartar (no formalizar) | — | — | [[0002]] |
| C.9 — Labels estándar | Diferir | — | — | [[0002]] |
| D.1 — Status checks obligatorios | Aplicar (por stack, vía reusables) | repo | 1 | [[0002]] |
| D.2 — Environments con reviewers | Diferir | — | 2 | [[0003]] |
| D.3 — Pinning de acciones | Aplicar (SHA terceros + `@v1` internos) | repo | 1 | [[0002]] |
| D.4 — `permissions:` mínimo en GITHUB_TOKEN | Aplicar | org | 0 | [[0002]] |
| D.5 — Allowed Actions allowlist | Aplicar (`selected` con GitHub + Verified + `Cosmos-SincoERP/*`) | org | 1 | [[0002]] |
| D.6 — Secrets org-level | Aplicar (transversales con `selected_repositories`) | org | 1 | [[0002]] |
| D.7 — Reusable workflows | Aplicar (uso obligatorio donde aplique stack) | repo | 1 | [[0002]] |
| D.8 — Concurrency control | Aplicar (como buena práctica documentada) | repo | 1 | [[0002]] |
| D.9 — OIDC / Managed Identity | Aplicar como recomendación fuerte (sin enforcement técnico) | repo | 1 | [[0002]] |
| D.10 — Required workflows org-wide | Descartar baseline (no disponible en Team) | — | — | [[0003]] |
| E.1 — Dependabot alerts | Aplicar | org | 0 | [[0002]] |
| E.2 — Dependabot security updates | Aplicar | org | 0 | [[0002]] |
| E.3 — Dependabot version updates | Aplicar (plantillas por stack en `.github`) | repo | 1 | [[0002]] |
| E.4 — Dependency review action | Aplicar (reusable en `Cosmos.PlatformWorkflows`) | repo | 1 | [[0002]] |
| E.5 — Secret scanning público | Documentar como activo; sin revisión formal | org | — | [[0002]] |
| E.6 — Secret scanning privado (mitigación) | Aplicar (reusable con `gitleaks` en `Cosmos.PlatformWorkflows`); revisar con GHAS | repo | 1 | [[0002]] / [[0003]] |
| E.7 — CodeQL / Code scanning | Diferir | — | 2 | [[0003]] |
| E.8 — Private vulnerability reporting | Diferir | — | 2 | [[0003]] |
| E.9 — `SECURITY.md` | Diferir | — | 2 | [[0003]] |
| E.10 — SBOM exports | Aplicar bajo demanda (export nativo) | — | — | [[0002]] |
| E.11 — SSO / SAML | Descartar baseline (no disponible en Team) | — | — | [[0003]] |

## Consecuencias

- ✅ **Marco compartido evita decisiones ad-hoc por repo**. Cada práctica del catálogo tiene una decisión registrada con justificación, en [[0002]] o [[0003]].
- ✅ **Trazabilidad de descartes**. Las prácticas que no se adoptan (PR template, issue templates, Draft PRs como convención formal) quedan documentadas con su razón; evita re-litigar la misma discusión en seis meses.
- ✅ **Mecanismo de segmentación disponible cuando se necesite**. Custom properties como targeting de Rulesets quedan habilitadas para activarse en [[0003]] sin tener que rehacer el modelo.
- ✅ **Aprovecha activos previos**. Las decisiones de CI/CD apuntan a `Cosmos.PlatformWorkflows` (8 reusables ya construidos) y al piloto `ObligacionesPorPagar.Radicacion` en vez de proponer alternativas paralelas.
- ⚠️ **Costo de mantenimiento del marco**. La efectividad depende de que la `Cosmos-SincoERP/.github` se mantenga actualizada y de que los reusables de `Cosmos.PlatformWorkflows` se consuman consistentemente.
- ⚠️ **Brechas residuales por falta de GHAS**. Sin Advanced Security, secret scanning + push protection en repos privados y CodeQL en privados quedan cubiertos por mitigaciones manuales (gitleaks en CI, push rulesets de paths). [[0003]] documenta cómo reevaluar al subir a Enterprise.
- ⚠️ **Sin tiering por ahora**. El baseline único en [[0002]] aplica igual a un sandbox que a un servicio core. Esa diferenciación queda pendiente hasta [[0003]] (o ADR posterior si la necesidad surge antes).

## Referencias

- [GitHub Docs — Repository rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets)
- [GitHub Docs — Custom repository properties](https://docs.github.com/en/organizations/managing-organization-settings/managing-custom-properties-for-repositories-in-your-organization)
- [GitHub Docs — Dependabot configuration](https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file)
- [GitHub Docs — About community health files](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file)
- [GitHub Docs — Configuring OpenID Connect in cloud providers](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [MADR — Markdown Architecture Decision Records](https://adr.github.io/madr/)
- [Michael Nygard — Documenting Architecture Decisions (2011)](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- Cosmos-SincoERP/Cosmos.PlatformWorkflows — workflows reutilizables ya implementados.
- Cosmos-SincoERP/ObligacionesPorPagar.Radicacion — piloto interno con branch protection + ruleset.
- [[0002]] — Políticas de repositorios: ambiente de desarrollo.
- [[0003]] — Políticas de repositorios: ambiente de producción.
