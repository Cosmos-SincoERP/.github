---
status: proposed
date: 2026-05-30
deciders: [augusto-romero-arango]
consulted: []
informed: []
---

# 0005 — Golden path: scaffold mínimo (baseline + seguridad); CI/CD deferido al onboarding

## Contexto y problema

[[0004]] adoptó el golden path de creación y, con él, el concepto de **arquetipo**: cada
tipo de repo recibía al crearse no solo el baseline de gobernanza sino su **CI/CD completo**
(build/deploy, publicación de paquete, plan/apply de infraestructura, etc.).

Ese CI/CD por arquetipo tiene un defecto de fondo: se genera **a ciegas**, en el momento en
que el repo nace vacío. El golden path no puede descubrir nada del repo (proyectos reales,
Dockerfiles, dependencias) ni conoce los valores reales del bounded context (registro de
imágenes, secretos, grupo de runners, redes). Emite un esqueleto con marcadores y `TODO`s
que, además, puede omitir parámetros que los workflows reusables exigen — de modo que el
CI/CD scaffoldeado puede nacer roto y bloquear el primer merge.

El mismo CI/CD lo generan, mucho mejor, las **skills de onboarding**: son interactivas,
escanean el repo cuando ya tiene código y rellenan los valores reales del bounded context.
Mantener dos generadores del mismo artefacto (uno ciego al crear, uno con contexto al
onboarding) duplica superficie y deja al primero permanentemente incompleto.

Por otro lado, el `dependabot.yml` ya lo gestiona el sync/drift de gobernanza (keyed en
`consumes`/`stack` del manifest); que el golden path además lo renderice al crear es
redundante.

Pregunta de decisión: ¿qué debe producir el golden path al crear un repo, y qué se defiere
a las skills de onboarding (o al equipo)?

## Drivers de decisión

Heredados de [[0001]]:

1. Consistencia de gobierno — un repo nace conforme al baseline y bajo gobernanza.
2. Fricción mínima — sin pasos manuales ni artefactos rotos que el equipo deba arreglar.
3. Una sola fuente por responsabilidad — evitar dos generadores del mismo artefacto.
4. Adaptación al flujo IA — el descubrimiento del CI/CD encaja mejor en una skill
   interactiva con contexto del bounded context que en un scaffold headless.

## Opciones consideradas

- **A. Statu quo (CI/CD por arquetipo).** El golden path scaffoldea el CI/CD completo de
  cada tipo (con `TODO`s) y la skill de onboarding lo regenera después. Doble fuente; el
  scaffold queda incompleto/roto hasta que alguien lo arregla a mano o corre la skill.
- **B. Enriquecer el scaffold.** Portar el descubrimiento (scan de proyectos/Dockerfiles,
  valores del bounded context) al propio golden path. Inviable: el repo nace vacío, no hay
  nada que descubrir en el momento de la creación.
- **C. Minimizar el golden path y retirar el arquetipo.** El golden path deja un único
  scaffold para todo repo: **baseline + seguridad**, sin diferenciar por tipo. Todo el
  CI/CD —de cualquier tipo— lo añaden las skills de onboarding (o el equipo) cuando el repo
  ya tiene código y existe la infra del bounded context. El `dependabot.yml` queda a cargo
  del sync/drift, como ya estaba.

## Decisión

Se adopta la **opción C**, que **retira el concepto de arquetipo** que introducía [[0004]]
y reemplaza los *checks requeridos por arquetipo* por un único baseline de seguridad:

1. **Un solo scaffold para todo repo nuevo: baseline + seguridad.** El golden path coloca
   los workflows de seguridad gestionados y nada más. No hay catálogo de arquetipos ni
   variantes por tipo de repo, y la acción de creación deja de pedir tipo, bounded context,
   visibilidad ni descripción: solo el nombre del repo.
2. **Todo el CI/CD lo añade el onboarding, no la creación.** Build/deploy, publicación de
   paquetes, plan/apply de infraestructura, skeletons de aplicación, etc. son
   responsabilidad de las skills de onboarding (con contexto del bounded context) o del
   equipo. El golden path nunca los emite.
3. **Required checks = solo los de seguridad.** El repo-level ruleset que aplica la creación
   marca como requeridos únicamente los checks del baseline de seguridad.
4. **El `dependabot.yml` no se renderiza al crear.** El sync/drift lo coloca y mantiene
   según el manifest. El repo nace en el stack baseline; cuando el equipo actualiza el
   manifest al stack real, el sync re-renderiza el `dependabot.yml`.

## Consecuencias

- ✅ Un solo generador del CI/CD (las skills / el equipo, con contexto real); el golden path
  deja de emitir artefactos incompletos.
- ✅ La acción de creación es trivial de operar: pide solo el nombre del repo (+ `dry_run`).
  Desaparece la fricción de elegir arquetipo, bounded context, visibilidad y demás.
- ✅ El repo sigue naciendo conforme: baseline + seguridad, bajo gobernanza desde el registro
  en el manifest. El `dependabot.yml` tiene una sola fuente (sync/drift).
- ⚠️ **Ventana sin CI/CD.** Entre crear el repo y añadir su CI/CD (por skill o a mano) el
  repo no tiene workflows de build/deploy/publish. Es intencional — ese CI/CD depende de que
  exista el código y la infra del bounded context.
- ⚠️ **Cobertura desigual del onboarding.** Hoy no toda clase de repo tiene una skill de
  onboarding que le devuelva su CI/CD; para esas (p. ej. librerías o frontends), el CI/CD se
  añade a mano hasta que exista la skill correspondiente. Es una regresión consciente frente
  al statu quo, aceptada a cambio de una sola fuente del CI/CD.
- ⚠️ **Catálogo retirado.** Se elimina el catálogo de arquetipos (plantillas por tipo). Si en
  el futuro se quiere volver a scaffoldear contenido por tipo, será por la vía de las skills,
  no del golden path.

## Referencias

- [[0004]] — Golden path de creación de repositorios (este ADR retira de su decisión el
  concepto de arquetipo y los checks por arquetipo; ver el Control de cambios de [[0004]]).
- [[0002]] — Políticas de repositorios: desarrollo (§B.1, §D.1, §E.3 sync/drift).
