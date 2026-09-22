---
status: accepted
date: 2026-09-22
deciders: [augusto-romero-arango]
consulted: []
informed: []
---

# 0003 — Políticas de repositorios: ambiente de producción

## Contexto y problema

Hereda el marco general de [[0001]] y el baseline de desarrollo de [[0002]]. La organización opera dos ambientes: **desarrollo** y **producción**. Producción sirve a clientes desde una suscripción dedicada, con varios bounded contexts y el plano de aplicación aprovisionados y con despliegues productivos en curso. Las decisiones de [[0002]] siguen rigiendo el día a día de los repos; este ADR registra lo que la existencia de producción agrega encima.

Este ADR cubre:
1. Las prácticas del catálogo de [[0001]] que [[0002]] difirió a producción.
2. Prácticas nuevas que solo aplican en presencia de producción (environments, tag protection).
3. Cambios de configuración de prácticas ya aplicadas en [[0002]] (potencial subida de approvals, signed commits, etc. para repos críticos).
4. Activación del mecanismo de **custom properties** que [[0001]] adoptó como marco pero cuyos valores específicos se postergaron.
5. Las **decisiones de plataforma** con las que se aprovisionó producción (suscripción, red, naming, state, gate de despliegue, registry) en la medida en que condicionan el contrato de los reusables y la operación de los repos.

Pregunta de decisión: ¿bajo qué modelo se suma producción al gobierno de los repos, qué prácticas adicionales se activan y cuáles siguen diferidas?

Restricción que condiciona todo el ADR: la organización está en plan **Team** con repos privados. Los *required reviewers* de GitHub Environments exigen Enterprise y no están disponibles; los Environments con secrets/vars propios y las *deployment branch policies* sí lo están.

## Drivers de decisión

Heredados de [[0001]]:

1. Reducción de superficie de riesgo (sube en producción: el blast radius de un bug incluye usuarios reales).
2. Consistencia de gobierno entre repos (con tiering, "consistencia por tier").
3. Fricción mínima viable para devs (puede subir tolerancia para repos críticos).
4. Adaptación al flujo IA (la gate humana antes de prod sube su valor).

Drivers nuevos:
- Auditoría y trazabilidad de cambios productivos: quién promovió qué, cuándo y desde qué commit.
- Paridad con desarrollo: lo que llega a producción debe ser lo mismo que se probó en desarrollo, sin rebuilds ni configuración divergente por accidente.
- Costo de entrada acotado: producción arranca en fase de pilotos y no justifica todavía rediseñar red, tiers ni plan de GitHub.

## Opciones consideradas — modelos para sumar producción al gobierno

- **A. Solo agregar environments + tag protection**: sumar la capa de despliegue al baseline de [[0002]] sin tocar el resto. Simple; no diferencia repos críticos.
- **B. Subir baseline para todos los repos uniformemente**: al llegar prod, endurecer todo el baseline (subir a 2 approvals, activar signed commits, push restrictions) para el portafolio entero. Simple de aplicar; trata igual sandbox y crítico.
- **C. Activar segmentación por custom properties y diferenciar por tier**: materializar el mecanismo de tiering que [[0001]] dejó disponible. Definir custom property `repo-tier` con valores, clasificar el portafolio, aplicar capas según tier.
- **D. Subir a Enterprise + GHAS y rehacer el modelo**: el upgrade habilita required workflows org-wide, push protection en privados, CodeQL en privados, SAML/SSO. Re-evaluar el portafolio bajo el nuevo set de herramientas. Decisión económica que se evalúa como información, no se toma en este ADR.

## Decisión (modelo)

Se adopta el **modelo A — sumar la capa de despliegue al baseline de [[0002]]**, uniforme para todo repo que despliega a producción:

- Se agregan **GitHub Environments por ambiente** y un **gate de promoción a producción** (acto deliberado desde `main`, validado contra un team autorizado). Ver D.2 y la sección de decisiones de plataforma.
- El resto del baseline de [[0002]] no se endurece por la llegada de producción.
- **Sin tiering** (C) y **sin upgrade a Enterprise** (D) en esta fase. Ambos siguen disponibles como evoluciones y no son excluyentes entre sí; las prácticas que dependen de ellos quedan diferidas con su condición de activación.
- Tag protection (B.11), parte natural de la opción A, sigue diferida: ver su sección.

Justificación: producción arranca como réplica de desarrollo en fase de pilotos (driver de costo de entrada). La superficie de riesgo nueva es el acto de promover a producción, y es exactamente lo que cubre la capa de despliegue. Diferenciar repos por tier no tiene hoy una necesidad funcional que lo justifique.

## Decisiones de plataforma de producción

Estas decisiones se tomaron al aprovisionar producción. Se registran aquí porque condicionan el contrato de los reusables de este repo y la operación de todos los repos que despliegan. Los identificadores (A1…A12, D-ACR) son los del plan de aprovisionamiento de producción, que conserva la justificación completa y la evidencia de cada una, y los que citan los reusables en sus comentarios.

**Directiva rectora**: producción es **réplica de desarrollo** en función y postura de seguridad. Los únicos deltas admitidos son de forma u operación (naming, región, rangos de red propios, suscripción, state, identidad de despliegue y gate). Ninguna pieza de producción endurece nada por cuenta propia: todo endurecimiento se hace primero en desarrollo.

#### A11 — Suscripción dedicada
- **Decisión**: producción vive en una suscripción propia, en el mismo tenant que desarrollo.
- **Justificación**: aísla blast radius, RBAC y cuotas de servicios gestionados; separa por diseño la identidad de despliegue de producción de la de desarrollo.
- **Consecuencia**: la identidad de despliegue y los backends de state de producción son nuevos; nada de desarrollo se reutiliza por nombre.

#### A1 — Red: réplica exacta de desarrollo
- **Decisión**: la red de producción copia la de desarrollo tal cual — redes aisladas por stack con exposición pública filtrada por reglas de red, **sin peering, sin private endpoints y sin DNS privado**. Único delta: rangos de direcciones propios y no solapados con desarrollo, para que un peering futuro sea posible sin renumerar.
- **Justificación**: paridad con lo probado y costo de entrada acotado.
- **Deuda aceptada**: la postura de red de producción hereda las aperturas y atajos de desarrollo. Su cierre es un endurecimiento que se hace primero en desarrollo y después se replica.

#### A2 — Naming y tagging
- **Decisión**: naming **CAF determinista** con el ambiente codificado en el nombre (`<tipo>-<carga>-<ambiente>-<región>-<instancia>`) en todos los stacks de producción, sin sufijos aleatorios; tagging con la convención de la plantilla canónica de infraestructura (claves en camelCase). Desarrollo no se migra.
- **Justificación**: nombres predecibles antes del apply eliminan encadenamientos manuales entre stacks y hacen verificable por forma a qué ambiente pertenece un recurso.

#### A4 — Ambiente como input de los reusables de Terraform
- **Decisión**: los reusables de plan y apply reciben el ambiente como input (con desarrollo como default retrocompatible). De él derivan el backend de state, el GitHub Environment que declara el job y la variable de ambiente de Terraform.
- **Justificación**: un solo contrato para ambos ambientes; el ambiente es un dato, no una bifurcación del reusable.

#### A6 — State por stack
- **Decisión**: una cuenta de state por stack dentro de la suscripción de producción, con el nombre de la cuenta, del grupo de recursos y de la clave derivados del stack y del ambiente según la convención de A2.
- **Justificación**: replica el patrón de desarrollo y mantiene separado el blast radius del state por stack y por ambiente.

#### A9 — GitHub Environments por repo
- **Decisión**: cada repo que despliega tiene Environments `dev` y `prod`. Variables y secrets que dependen del ambiente viven en el Environment, con el **mismo nombre en ambos** para que el contrato de los reusables no cambie. `prod` tiene *deployment branch policy* restringida a `main`.
- **Regla operativa**: todo valor que difiera por ambiente vive en el Environment, **nunca a nivel repo ni org**. GitHub resuelve Environment → repo → org, así que un valor de desarrollo definido a nivel repo y ausente en `prod` se resuelve en silencio en un despliegue de producción.
- **Justificación**: disponible en Team para repos privados; separa configuración por ambiente sin duplicar workflows.

#### A5 — Gate de promoción a producción
- **Decisión**: PR ejecuta solo plan; merge a `main` aplica y despliega desarrollo automáticamente; producción se promueve **solo por `workflow_dispatch` sobre `main`**, y el run valida que quien lo dispara (y quien lo re-ejecuta) sea miembro activo del team autorizado del repo. El humano que dispara es la aprobación, auditada en el run.
- **Alcance**: aplica a los reusables de apply de infraestructura y a los de despliegue de aplicaciones y fronts. En ellos rige el invariante **producción ⇒ gate**: un caller de producción que omite el team no despliega sin gate, falla cerrado.
- **Justificación**: sustituye a los *required reviewers* de Environments, que exigen Enterprise. Cubre la misma superficie —nadie fuera del team promueve, y nunca desde una rama que no sea `main`— sin cambiar de plan.

#### D-ACR — Producción consume el registry de desarrollo
- **Decisión**: no hay registry de imágenes por ambiente. Producción despliega desde el registry de desarrollo de su bounded context, con acceso de solo lectura para su identidad de despliegue. Los registries siguen siendo **uno por bounded context**, para imputación de costos.
- **Justificación**: la imagen que llega a producción es bit a bit la que corrió en desarrollo; la promoción es por tag, nunca por rebuild.
- **Consecuencias**: la retención del registry debe proteger lo que producción tiene desplegado, que va por detrás de desarrollo; y las validaciones de coherencia ambiente↔recursos de los reusables excluyen el registry, que legítimamente lleva el marcador de desarrollo también en producción.

## Decisiones por práctica

### Prácticas diferidas desde [[0002]]

#### A.3 — Política de creación de repositorios
- **Estado**: diferida desde [[0002]] por limitación del plan Team.
- **Origen**: la combinación deseada (restringir creación pública preservando creación privada) no es expresable bajo Team; los toggles disponibles no permiten esa combinación.
- **Opciones de tratamiento** post-upgrade Enterprise:
  - Activar restricción de creación pública conservando creación privada.
  - Restringir creación de cualquier repo a un team aprobado (más estricto).
  - Mantener el estado actual si el riesgo se considera tolerable bajo controles compensatorios.
- **Condición de activación**: upgrade a plan Enterprise.

#### B.6 — Require signed commits
- **Estado**: diferida.
- **Opciones de tratamiento** cuando se aborde:
  - Activar para tier `critical` solamente (con plan de rollout de configuración GPG/SSH para devs y agentes IA).
  - Activar org-wide.
  - Mantener descartada (alto costo de setup vs valor).
- **Condición de activación**: cuando un cliente o un requisito de compliance lo exija, o al activar tiering. La existencia de producción, por sí sola, no la activó.

#### B.11 — Tag protection rules
- **Estado**: diferida.
- **Opciones de tratamiento**:
  - Activar Tag ruleset org-wide protegiendo `v*` y `release-*` contra creación/borrado por actores no autorizados.
  - Activar solo en repos con tier `critical` o que publiquen releases.
  - Activar de forma parcial primero donde haya tags consumidos por toda la organización (p. ej. reusables internos referenciados por todos los consumidores).
- **Condición de activación**: cuando exista un proceso de release con tags git que sirvan a despliegue productivo, o ya antes para proteger los tags de los reusables internos. La promoción a producción de hoy no usa tags git (va por `workflow_dispatch` sobre `main`, ver A5), así que su llegada no la activó.

#### D.2 — Environments con required reviewers
- **Decisión**: Aplicar **sin required reviewers**. Environments `dev` y `prod` por repo (A9), con *deployment branch policy* `main` en `prod`; el gate humano lo da el `workflow_dispatch` validado contra el team autorizado (A5).
- **Justificación**: los required reviewers exigen Enterprise. Sin ambiente de staging, un Environment intermedio no aporta. Reevaluar los required reviewers nativos si se sube a Enterprise.

#### D.10 — Required workflows org-wide
- **Estado**: descartada para Team. Reevaluar si se sube a Enterprise.
- **Opciones de tratamiento** post-upgrade:
  - Activar required workflows org-wide para compliance/security checks (dependency review, secret scan, license check).
  - Mantener mecanismo actual (D.1 status checks + reusables + bootstrap).
- **Condición de activación**: upgrade a Enterprise.

#### E.6 — Secret scanning + push protection en privados (GHAS)
- **Estado**: mitigado en [[0002]] con reusable OSS. Reevaluar si se sube a Enterprise + GHAS.
- **Opciones de tratamiento** post-upgrade:
  - Activar GHAS secret scanning + push protection nativo; retirar el reusable OSS o mantenerlo como defensa en profundidad.
  - Mantener ambos (defensa en profundidad).
- **Condición de activación**: upgrade a Enterprise + GHAS.

#### E.7 — Code scanning / CodeQL
- **Estado**: diferida.
- **Opciones de tratamiento**:
  - Activar CodeQL en los repos públicos (gratis); diferir privados.
  - Reusables `_reusable-codeql.yml` para públicos + `_reusable-semgrep.yml` (OSS rules) para privados.
  - Esperar GHAS para cobertura completa pública + privada con CodeQL nativo.
  - Descartar SAST por completo (decisión explícita).
- **Condición de activación**: al evaluar upgrade Enterprise/GHAS, o si un requisito de cliente o compliance exige SAST antes.

#### E.8 — Private vulnerability reporting
- **Estado**: diferida.
- **Opciones de tratamiento**:
  - Activar org-wide.
  - Activar solo en repos públicos.
  - Mantener diferido.
- **Condición de activación**: cuando se decida activar también E.9 (canal documentado en SECURITY.md).

#### E.9 — `SECURITY.md`
- **Estado**: diferida.
- **Opciones de tratamiento**:
  - Plantilla en el repo `.github` de la org con canal de reporte (PVR si E.8 activado, mail dedicado en caso contrario), versiones soportadas, política de respuesta.
  - Solo en repos públicos.
  - Mantener descartado.
- **Condición de activación**: conjunta con E.8.

#### E.11 — SSO / SAML
- **Estado**: descartada para Team. Reevaluar si se sube a Enterprise.
- **Opciones de tratamiento** post-upgrade:
  - Integrar con el IdP corporativo para autenticación de miembros.
  - Mantener gestión manual (rara vez justificable post-upgrade).
- **Condición de activación**: upgrade a Enterprise.

### Práctica nueva: activación del tiering (B.14 valores)

#### Tiering por `repo-tier`
- **Estado**: diferido. El mecanismo está disponible desde [[0001]] (modelo D); no se definen valores en esta fase (ver Decisión).
- **Opciones de valores propuestas** (a refinar al decidir):
  - `critical | standard | sandbox` (tres niveles)
  - `critical | standard` (dos niveles)
  - `production | non-production` (dos niveles, semántico)
  - Otras combinaciones
- **Otras custom properties potencialmente útiles**:
  - `stack`: para targeting de reusables o políticas específicas por stack.
  - `domain`: dominio funcional, para reporting y CODEOWNERS.
- **Condición de activación**: cuando la diferenciación por tier sea funcionalmente necesaria — p. ej. repos con requisitos de disponibilidad o compliance que no se quieran imponer al resto.

### Posible cambio: subir N approvals para repos críticos (B.2)

- **Estado**: en [[0002]] se decidió `0 approvals` (require PR solamente). Para repos `critical` en producción, evaluar subir a 1 o 2.
- **Opciones**:
  - 1 approval para `critical`, mantener 0 para resto.
  - 2 approvals para `critical`, 1 para `standard`, 0 para `sandbox`.
  - Mantener 0 universalmente y confiar en checks de CI + dependency review + secret scan + CODEOWNERS.
- **Condición de activación**: al activar tiering.

### Posible cambio: restringir who can push (B.10)

- **Estado**: en [[0002]] se decidió no restringir. Para ramas de release de repos `critical`, evaluar restringir a team de plataforma.
- **Condición de activación**: al activar tiering.

---

## Consideración: upgrade a Enterprise + GHAS

**No es decisión que se tome en este ADR**, solo información para futura evaluación.

Capacidades que se desbloquean:

| Capacidad | Hoy en Team (mitigación) |
|---|---|
| Secret scanning + push protection en repos privados | Reusable OSS (E.6 en [[0002]]) + push rulesets de paths (B.12) |
| CodeQL en repos privados | Diferido (E.7) — alternativa OSS si se requiere antes |
| Required workflows org-wide | Status checks bloqueantes vía Ruleset + reusables consumidos manualmente (D.1 + D.7) |
| SAML / SSO | Gestión manual de identidades en GitHub |
| Audit log streaming | Retención y consulta limitadas a UI/API estándar |

Señales que harían que evaluar el upgrade tenga sentido:
- Crecimiento del equipo más allá del rango donde la gestión manual de identidades es viable.
- Requisitos contractuales de clientes (SOC 2, ISO 27001, similares).
- Sensibilidad alta de datos manejados en producción.
- Incidentes de secretos filtrados que las mitigaciones OSS no atajaron.
- Necesidad de auditoría centralizada para compliance.
- Coste anual estimado de las mitigaciones manuales superando el delta de costo de Enterprise + GHAS.

## Consecuencias

- ✅ **La promoción a producción es un acto deliberado y auditado**: solo desde `main`, solo por un miembro del team autorizado, con el run como registro. Sin depender de Enterprise.
- ✅ **Paridad desarrollo↔producción por construcción**: mismo código de workflow con el ambiente como input, mismas imágenes (D-ACR), mismos SKUs y red. Lo que se probó en desarrollo es lo que corre en producción.
- ✅ **Recursos verificables por forma**: el naming determinista con el ambiente codificado permite que los reusables validen coherencia ambiente↔recursos y fallen cerrado ante un caller mal cableado.
- ⚠️ **Deuda de red aceptada (A1)**: producción hereda la postura de red de desarrollo. Se mitiga endureciendo primero desarrollo; ninguna pieza de producción diverge por su cuenta.
- ⚠️ **Precedencia de variables como trampa (A9)**: un valor por ambiente definido a nivel repo u org se filtra en silencio a producción si falta en el Environment `prod`. Se mitiga con la regla operativa de A9 y documentando la precedencia en cada reusable que resuelve `vars`.
- ⚠️ **Registry compartido entre ambientes (D-ACR)**: la retención del registry de desarrollo pasa a proteger imágenes de producción; una poda ciega le borraría a producción lo que tiene corriendo. Se mitiga excluyendo de la poda el conjunto desplegado en ambos ambientes.
- ⚠️ **Sin tiering ni Enterprise**: signed commits, tag protection, SAST y secret scanning nativo en privados siguen diferidos o como mitigaciones OSS.

## Control de cambios

- **2026-09-22** — Pasa de `proposed` a `accepted` al registrar un ambiente de producción ya operando. Se retira la nota de estado que condicionaba el ADR a la existencia de producción; se rellenan Decisión (modelo A) y Consecuencias; se agrega la sección de decisiones de plataforma de producción (A1, A2, A4, A5, A6, A9, A11, D-ACR); D.2 pasa de opciones a decisión; el resto de las prácticas pasa de "pendiente" a "diferida" con su condición de activación actualizada.

## Referencias

- [[0001]] — Marco de gobernanza y políticas de repositorios.
- [[0002]] — Políticas para ambiente de desarrollo.
- [GitHub Docs — Environments and deployments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [GitHub Docs — Tag protection rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-tag-protection-rules)
- [GitHub Docs — Custom repository properties](https://docs.github.com/en/organizations/managing-organization-settings/managing-custom-properties-for-repositories-in-your-organization)
- [GitHub Advanced Security overview](https://docs.github.com/en/get-started/learning-about-github/about-github-advanced-security)
- [GitHub Enterprise SAML SSO](https://docs.github.com/en/enterprise-cloud@latest/admin/identity-and-access-management/using-saml-for-enterprise-iam/about-identity-and-access-management-with-saml-single-sign-on)
