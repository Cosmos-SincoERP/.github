---
status: proposed
date: 2026-05-28
deciders: [augusto-romero-arango]
consulted: []
informed: []
---

# 0004 — Golden path de creación de repositorios

## Contexto y problema

Hereda el marco de [[0001]] y el baseline de desarrollo de [[0002]]. La regla de no
permitir push directo a `main` ya está garantizada org-wide ([[0002]] §B.1) y aplica a
cualquier repo nuevo apenas tiene rama por defecto. El problema no es *enforzar* esa
regla, sino la **creación** de un repo: hoy es manual y post-hoc — se crea el repo, se le
pega el scaffold de CI/CD a mano o con asistencia, y solo después alguien lo registra en
el inventario que gobierna el sync y el drift-check.

Ese flujo deja ventanas de inconsistencia: repos sin los settings de merge esperados, sin
los checks requeridos, o que existen un tiempo fuera del inventario (y por tanto fuera de
la gobernanza automatizada). La experiencia para quien crea un repo es pobre: necesita
conocer todos los pasos y replicarlos sin omisiones.

Pregunta de decisión: ¿qué mecanismo adopta la organización para que crear un repo
produzca, desde el minuto cero, un repo conforme al baseline y ya inventariado para la
gobernanza?

> Esta decisión es ortogonal a [[0002]] §A.3 (*restricción de quién puede crear repos*),
> que sigue diferida por limitación del plan. A.3 limita el acceso a la creación; este ADR
> define el **proceso** de creación conforme. Cuando A.3 se active, este golden path será
> el canal natural por el que pase esa creación.

## Drivers de decisión

Heredados de [[0001]], con su orden de prioridad:

1. Consistencia de gobierno entre repos — un repo nuevo no debe poder nacer fuera del
   baseline ni fuera del inventario.
2. Fricción mínima viable para devs — crear un repo debe ser una sola acción guiada, no
   una checklist manual.
3. Reducción de superficie de riesgo — concentrar el privilegio de creación en un canal
   auditable.
4. Adaptación al flujo IA — un proceso determinista y repetible es preferible a uno que
   dependa de que un agente recuerde todos los pasos.

## Opciones consideradas

- **A. Plantillas de repositorio nativas ("usar esta plantilla")**: una plantilla por
  tipo de repo. Cero infraestructura y self-service; el scaffold es el primer commit, sin
  fricción con la regla de no-push. Pero las plantillas son copias-snapshot sin
  parametrización, no aplican settings ni registran el repo en el inventario, y exigen
  mantener tantas plantillas como tipos.

- **B. Flujo de creación centralizado en el repo de gobernanza**: una acción manual que
  crea el repo, le aplica los settings que el baseline org no cubre, scaffoldea el baseline
  y lo registra en el inventario de una vez.
  Reaprovecha la maquinaria de sync y drift ya existente y deja una sola fuente que
  mantener. Requiere construirlo y otorgar privilegio de creación a una identidad de
  automatización.

- **C. Scaffold conversacional asistido por IA**: extender las skills de onboarding
  existentes para orquestar la creación. Máxima flexibilidad y contexto, alineado con el
  flujo de trabajo actual; pero no es un gate determinista ni repetible, depende de que un
  humano lo invoque y corre con credenciales personales.

- **D. Repos como código (IaC)**: declarar repos, settings y reglas en un proveedor de
  infraestructura con detección de drift nativa. Es el modelo más completo a largo plazo,
  pero es pesado para la madurez actual: introduce estado de infraestructura, una identidad
  con privilegio amplio y la migración del portafolio existente, duplicando en parte lo que
  el inventario liviano ya resuelve.

## Decisión

Se adopta la **opción B — flujo de creación centralizado en el repo de gobernanza**, con
estas características de diseño a nivel de decisión:

1. **El inventario es fuente de verdad desde la creación.** El flujo registra el repo nuevo
   en el inventario como parte del acto de crearlo (forward), de modo que el sync y el
   drift-check lo gobiernan inmediatamente. El mecanismo de detección post-hoc existente se
   conserva solo para incorporar repos heredados (backfill).

2. **Identidad de automatización como excepción acotada a la regla de no-push.** El commit
   inicial de un repo recién creado no puede entrar por PR (no existe aún una rama base
   contra la cual abrirlo). Se autoriza a la identidad de automatización del proceso a
   sembrar ese **primer commit** de la rama por defecto como excepción explícita y auditable
   a [[0002]] §B.1. Todo cambio posterior — incluido el registro del repo en el inventario —
   sigue pasando por PR. La excepción se limita al bootstrap y a esa única identidad.

> El alcance del scaffold y los checks que aplica la creación se definen en [[0005]]
> (baseline de seguridad, sin arquetipos). Ver Control de cambios.

## Consecuencias

- ✅ Un repo nace conforme al baseline y ya inventariado: se cierra la ventana entre "repo
  creado" y "repo gobernado".
- ✅ Crear un repo pasa a ser una sola acción guiada, reduciendo la fricción y el
  conocimiento tácito requerido.
- ✅ Reaprovecha la maquinaria de gobernanza existente (inventario + sync + drift) en vez de
  introducir un sistema paralelo.
- ⚠️ **Privilegio concentrado.** La identidad de automatización gana capacidad de crear
  repos y de sembrar el commit inicial saltando la regla de no-push. Es un blast radius
  mayor si esa identidad se compromete; mitigación: se adopta una **identidad dedicada de
  creación**, separada de la del sync, con permisos granulares mínimos, y la excepción a la
  regla de no-push se limita al bootstrap y a esa identidad.
- ⚠️ **Ventana de inventario.** Entre crear el repo y aceptar su registro en el inventario
  hay un intervalo en el que el repo podría aparecer como no clasificado; se acota cerrando
  ese registro de inmediato.
- ⚠️ **Contrato de nombres de checks.** Marcar checks como requeridos depende de que su
  identificador coincida exactamente con el que reporta la plataforma; un desajuste bloquea
  merges hasta corregirlo. Mitigación: verificar empíricamente tras el primer cambio.

## Referencias

- [[0001]] — Marco de gobernanza y políticas de repositorios.
- [[0002]] — Políticas de repositorios: ambiente de desarrollo (§A.3, §B.1, §C.4–C.6, §D.1,
  §D.7, §E.3).
- [[0003]] — Políticas de repositorios: ambiente de producción (§A.3, §D.2).
- [[0005]] — Golden path: scaffold mínimo (refina esta decisión; ver Control de cambios).

## Control de cambios

- **2026-05-30** — Se retiran del cuerpo dos características de diseño invalidadas por
  [[0005]] (que minimiza el golden path a baseline + seguridad): el **concepto de
  "arquetipo"** (capa de scaffold por tipo de repo, con su catálogo de seis tipos) y los
  **checks requeridos por arquetipo**. La creación deja de scaffoldear CI/CD por tipo y de
  declarar checks por arquetipo; el resto de la decisión —flujo centralizado, inventario
  como fuente de verdad e identidad de automatización como excepción al no-push— sigue
  vigente. Se eliminó también el catálogo de plantillas de arquetipos. El contexto, las
  opciones y las consecuencias que asumían ese modelo se ajustaron en consecuencia.
