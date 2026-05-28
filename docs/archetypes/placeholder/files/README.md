# {{REPO_NAME}}

{{DESCRIPTION}}

Repo baseline creado vía el golden path de `Cosmos-SincoERP/.github`
(arquetipo `placeholder`). Aún sin código de aplicación; solo recibe el baseline
de gobernanza: `security-checks` (dependency review + secret scan en PRs) y
`dependabot` (github-actions).

## Cuando el repo tenga código

Reclasificar al arquetipo/stack adecuado:

1. Correr `bash .github/scripts/scan-repo.sh {{REPO_NAME}}` desde el repo `.github`
   para obtener el bloque de manifest con el stack inferido y los overrides.
2. Editar la entrada de `{{REPO_NAME}}` en `docs/repos-manifest.yml` con ese bloque.
3. Añadir los wrappers de CI/CD del stack correspondiente (ver `docs/archetypes/`).

> `main` está protegido a nivel organización: todo entra por PR (ADR 0002 §B.1).
