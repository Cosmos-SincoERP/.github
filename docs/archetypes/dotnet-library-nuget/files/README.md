# {{REPO_NAME}}

{{DESCRIPTION}}

Librería .NET publicada a NuGet. Creada vía el golden path de
`Cosmos-SincoERP/.github` (arquetipo `dotnet-library-nuget`).

## CI/CD scaffoldeado

| Workflow | Evento | Qué hace |
|---|---|---|
| `pr-tests.yml` | PR a `main` | restore + build + test |
| `release-nuget.yml` | manual | bump SemVer → tag + Release → publish a NuGet |

## Pendientes al arrancar (TODO)

1. Crear el/los proyecto(s) `.csproj` de la librería y sus tests.
2. Ajustar el `resolver` de `release-nuget.yml` (package_id, tag_prefix, project_path).
3. Confirmar el secret `NUGET_API_KEY` (org-level, scoped a este repo).

> `main` está protegido a nivel organización: todo entra por PR (ADR 0002 §B.1).
