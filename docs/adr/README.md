# ADRs — Cosmos-SincoERP / `.github`

Estos ADRs documentan decisiones de **gobernanza operacional** de los repositorios y de la organización Cosmos-SincoERP. Su scope son políticas, configuraciones y procesos que afectan cómo operan los repos (no decisiones de arquitectura de producto — esas viven en el blog de ingeniería).

## Índice

| ID | Título | Status |
|---|---|---|
| [0001](0001-marco-gobernanza-repositorios.md) | Marco de gobernanza y políticas de repositorios | `accepted` |
| [0002](0002-politicas-repositorios-desarrollo.md) | Políticas de repositorios — ambiente de desarrollo | `accepted` |
| [0003](0003-politicas-repositorios-produccion.md) | Políticas de repositorios — ambiente de producción | `proposed` |
| [0004](0004-creacion-automatizada-repositorios.md) | Creación automatizada de repositorios | `proposed` |
| [0005](0005-creacion-repos-scaffold-minimo.md) | Creación de repos: scaffold mínimo (baseline + seguridad); CI/CD deferido al onboarding | `proposed` |

## Formato

Los ADRs usan **MADR-lite**: markdown plano con frontmatter mínimo + cuerpo Nygard (Contexto → Drivers → Opciones → Decisión → Consecuencias → Referencias). Sin dependencias de Jekyll u otro motor.

Ver [`template.md`](template.md) para la plantilla a copiar al crear un ADR nuevo.

## Numeración

Numeración propia del repo, secuencial desde `0001`. Cada nuevo ADR toma el siguiente número disponible.

## Cómo contribuir un ADR

1. Copiar `template.md` a `NNNN-slug-descriptivo-corto.md` (NNNN = próximo número, slug en kebab-case en español).
2. Rellenar contexto, drivers, opciones consideradas y decisión.
3. Abrir PR contra `main` con el ADR en `status: proposed`.
4. Discusión y ajustes en el PR.
5. Cuando se aprueba, cambiar a `status: accepted` antes de mergear.
6. Cuando una decisión posterior invalida una previa **no** se deja el ADR viejo en pie marcándolo `superseded`: si queda **totalmente** invalidado se **elimina**; si queda **parcialmente** invalidado se **borra del cuerpo la sección que ya no es coherente** y se documenta el recorte en una sección **Control de cambios** del propio ADR (fecha + qué se retiró + ADR que lo motiva). El objetivo es que una lectura del ADR —en especial por un LLM— nunca encuentre contenido obsoleto que induzca decisiones inconsistentes.

## Convención de referencias cruzadas

Entre ADRs se usa `[[NNNN]]` (estilo MADR). GitHub no lo auto-renderiza como link, pero es estable, busca-able y portable.
