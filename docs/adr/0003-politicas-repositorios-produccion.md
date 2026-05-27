---
status: proposed
date: 2026-05-25
deciders: [augusto-romero-arango]
consulted: []
informed: []
---

# 0003 — Políticas de repositorios: ambiente de producción

> **Estado**: este ADR está en `proposed` y se mantiene así hasta que se materialice un ambiente de producción (servicios desplegados de cara a clientes, datos productivos, requerimientos de disponibilidad/SLA). En ese momento se toman las decisiones marcadas como pendientes y el ADR pasa a `accepted`.

## Contexto y problema

Hereda el marco general de [[0001]] y el baseline de desarrollo de [[0002]]. Hoy no hay ambiente de producción; las decisiones de gobernanza incluidas en [[0002]] son suficientes para dev pero quedan abiertas para cuando exista prod.

Este ADR cubre:
1. Las prácticas del catálogo de [[0001]] que [[0002]] difirió a producción.
2. Prácticas nuevas que solo aplican en presencia de producción (environments, tag protection).
3. Cambios de configuración de prácticas ya aplicadas en [[0002]] (potencial subida de approvals, signed commits, etc. para repos críticos).
4. Activación del mecanismo de **custom properties** que [[0001]] adoptó como marco pero cuyos valores específicos se postergaron.

Pregunta de decisión (a tomar cuando producción se materialice): ¿qué tier de repos se define, qué prácticas adicionales activamos para qué tier, y bajo qué modelo se opera la diferenciación?

## Drivers de decisión

Heredados de [[0001]] (a confirmar al activar este ADR):

1. Reducción de superficie de riesgo (sube en producción: el blast radius de un bug incluye usuarios reales).
2. Consistencia de gobierno entre repos (con tiering, "consistencia por tier").
3. Fricción mínima viable para devs (puede subir tolerancia para repos críticos).
4. Adaptación al flujo IA (la gate humana antes de prod sube su valor).

Drivers nuevos potencialmente relevantes:
- Auditoría y trazabilidad de cambios productivos.
- Tiempo de respuesta a incidentes.
- Requisitos contractuales/compliance (si aplican cuando exista prod).

## Opciones consideradas — modelos para sumar producción al gobierno

- **A. Solo agregar environments + tag protection**: sumar la capa de despliegue al baseline de [[0002]] sin tocar el resto. Simple; no diferencia repos críticos.
- **B. Subir baseline para todos los repos uniformemente**: al llegar prod, endurecer todo el baseline (subir a 2 approvals, activar signed commits, push restrictions) para el portafolio entero. Simple de aplicar; trata igual sandbox y crítico.
- **C. Activar segmentación por custom properties y diferenciar por tier**: materializar el mecanismo de tiering que [[0001]] dejó disponible. Definir custom property `repo-tier` con valores, clasificar el portafolio, aplicar capas según tier.
- **D. Subir a Enterprise + GHAS y rehacer el modelo**: el upgrade habilita required workflows org-wide, push protection en privados, CodeQL en privados, SAML/SSO. Re-evaluar el portafolio bajo el nuevo set de herramientas. Decisión económica que se evalúa como información, no se toma en este ADR.

## Decisión (modelo)

> **A rellenar cuando producción se materialice.** Las opciones C y D no son mutuamente excluyentes (se puede activar tiering y luego subir a Enterprise para complementar).

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
- **Estado**: pendiente de decidir.
- **Opciones de tratamiento** cuando se aborde:
  - Activar para tier `critical` solamente (con plan de rollout de configuración GPG/SSH para devs y agentes IA).
  - Activar org-wide.
  - Mantener descartada (alto costo de setup vs valor).
- **Condición de activación**: cuando exista producción o cuando un cliente/compliance lo requiera.

#### B.11 — Tag protection rules
- **Estado**: pendiente de decidir.
- **Opciones de tratamiento**:
  - Activar Tag ruleset org-wide protegiendo `v*` y `release-*` contra creación/borrado por actores no autorizados.
  - Activar solo en repos con tier `critical` o que publiquen releases.
  - Activar de forma parcial primero donde haya tags consumidos por toda la organización (p. ej. reusables internos referenciados por todos los consumidores).
- **Condición de activación**: cuando exista proceso de release con tags que sirvan a despliegue productivo, o ya antes para proteger los tags de los reusables internos.

#### D.2 — Environments con required reviewers
- **Estado**: pendiente de decidir.
- **Opciones de tratamiento**:
  - Crear environments `staging` y `production` por repo con required reviewers + wait timer + branch restrictions.
  - Crear solo `production` con reviewers; `staging` sin reviewers.
  - No usar environments; gate humano se da vía aprobación de PR.
- **Condición de activación**: cuando exista despliegue a un ambiente productivo.

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
- **Estado**: pendiente de decidir.
- **Opciones de tratamiento**:
  - Activar CodeQL en los repos públicos (gratis); diferir privados.
  - Reusables `_reusable-codeql.yml` para públicos + `_reusable-semgrep.yml` (OSS rules) para privados.
  - Esperar GHAS para cobertura completa pública + privada con CodeQL nativo.
  - Descartar SAST por completo (decisión explícita).
- **Condición de activación**: revisar al materializarse producción O al evaluar upgrade Enterprise/GHAS.

#### E.8 — Private vulnerability reporting
- **Estado**: pendiente de decidir.
- **Opciones de tratamiento**:
  - Activar org-wide.
  - Activar solo en repos públicos.
  - Mantener diferido.
- **Condición de activación**: cuando se decida activar también E.9 (canal documentado en SECURITY.md).

#### E.9 — `SECURITY.md`
- **Estado**: pendiente de decidir.
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
- **Estado**: el mecanismo está disponible desde [[0001]] (modelo D); falta definir valores.
- **Opciones de valores propuestas** (a refinar al decidir):
  - `critical | standard | sandbox` (tres niveles)
  - `critical | standard` (dos niveles)
  - `production | non-production` (dos niveles, semántico)
  - Otras combinaciones
- **Otras custom properties potencialmente útiles**:
  - `stack`: para targeting de reusables o políticas específicas por stack.
  - `domain`: dominio funcional, para reporting y CODEOWNERS.
- **Condición de activación**: cuando la diferenciación por tier sea funcionalmente necesaria (típicamente al materializarse producción; podría ser antes si surge razón específica).

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

> **A rellenar cuando se acepte este ADR.** Esquema previsto:
>
> - ✅ Diferenciación por tier permite endurecer críticos sin friccionar sandboxes.
> - ✅ Environments + tag protection cubren la superficie de riesgo productiva.
> - ⚠️ Operativo: clasificación inicial del portafolio requiere alineación con dueños de servicio.
> - ⚠️ Subir approvals + signed commits en `critical` introduce fricción notable; gestionar comunicación.
> - ⚠️ Si no se sube a Enterprise, secret scanning y CodeQL en privados siguen como mitigaciones manuales.

## Referencias

- [[0001]] — Marco de gobernanza y políticas de repositorios.
- [[0002]] — Políticas para ambiente de desarrollo.
- [GitHub Docs — Environments and deployments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [GitHub Docs — Tag protection rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-tag-protection-rules)
- [GitHub Docs — Custom repository properties](https://docs.github.com/en/organizations/managing-organization-settings/managing-custom-properties-for-repositories-in-your-organization)
- [GitHub Advanced Security overview](https://docs.github.com/en/get-started/learning-about-github/about-github-advanced-security)
- [GitHub Enterprise SAML SSO](https://docs.github.com/en/enterprise-cloud@latest/admin/identity-and-access-management/using-saml-for-enterprise-iam/about-identity-and-access-management-with-saml-single-sign-on)
