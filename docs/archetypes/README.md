# Arquetipos de creación de repos

Cada subdirectorio es un **arquetipo**: la plantilla que `create-repo.yml`
(`.github/workflows/create-repo.yml`) usa para crear un repo nuevo ya gobernado.

Un arquetipo NO es lo mismo que el `stack` del manifest. El `stack`
(`dotnet | node-bun | terraform | github-actions`) es el eje del sync de
gobernanza. El arquetipo es el concepto de **creación**: mapea a un `stack` +
`overrides` por defecto + los workflows/archivos a scaffoldear + los checks que
se marcan como required en el repo nuevo.

Ver el ADR [`0004`](../adr/0004-creacion-automatizada-repositorios.md).

## Estructura de un arquetipo

```
docs/archetypes/<arquetipo>/
├── archetype.yml     # metadata consumida por create-repo.sh
└── files/            # árbol literal a scaffoldear en el repo nuevo
    └── ...           # con placeholders {{REPO_NAME}}, {{BC_KEY}}, {{DESCRIPTION}}
```

`archetype.yml`:

| Campo | Tipo | Descripción |
|---|---|---|
| `description` | string | Para qué sirve el arquetipo (se muestra en el resumen del workflow). |
| `stack` | string | Valor del manifest: `dotnet \| node-bun \| terraform \| github-actions`. |
| `consumes` | list | Qué consume del sync. Normalmente `[reusables, dependabot]`. |
| `bc_key_required` | bool | Si `true`, el workflow exige el input `bc_key` (clave del bounded context, ej. `oxp`). |
| `overrides` | map | `terraform_directory` / `docker_directories` por defecto del scaffold. Pueden contener `{{...}}`. |
| `required_checks` | list | Contextos EXACTOS de los checks que el repo-level ruleset marca required, en formato `<job-caller> / <job-del-reusable>` (ver nota abajo). |

## Sustitución de placeholders

`create-repo.sh` sustituye en `files/` y en `overrides`:

- `{{REPO_NAME}}` → nombre del repo (input `repo_name`).
- `{{BC_KEY}}` → clave del bounded context (input `bc_key`); vacío si no aplica.
- `{{DESCRIPTION}}` → descripción (input `description`).

Las variables de runtime de los workflows (`${ACR_LOGIN_SERVER}`, `${IMAGE_TAG}`,
`${VAR_NAME}` de `env.js.tmpl`, etc.) usan sintaxis `${...}` y **no se tocan**.

> ⚠️ `required_checks` es **contrato frágil**: el contexto debe coincidir EXACTO
> con lo que GitHub reporta. Para checks que vienen de un workflow reusable, el contexto
> es `<job-caller> / <job-del-reusable>` — **no** el `name:` raíz del reusable. Ej.: el job
> `dependency-review` que invoca el reusable cuyo job interno es `trivy` reporta como
> `dependency-review / trivy` (confirmado en PR #89). Para un job normal (no reusable), el
> contexto es el nombre del job. Si renombras un job en un wrapper, actualiza aquí.
