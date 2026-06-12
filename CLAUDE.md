# CLAUDE.md — guía para agentes en este repo

Repo `.github` de **Cosmos-SincoERP**: publica 14 workflows reusables
(`.github/workflows/_reusable-*.yml`) versionados **como un solo conjunto** con un
único **major móvil** (`v1`, `v2`, …). Los consumidores los fijan con `@vN`.
Detalle del versionado en [`.github/workflows/README.md`](.github/workflows/README.md).

## Al crear un PR — etiqueta de release (obligatorio si toca un reusable)

Antes de abrir un PR, comprueba si el diff toca algún `.github/workflows/_reusable-*.yml`
(p. ej. `git diff --name-only origin/main...`).

**Si toca un reusable**, el PR **debe** llevar exactamente una etiqueta de release.
**Pregúntale al usuario** cuál corresponde, explicando la consecuencia, y aplícala:

- **`release:move`** — cambio **no-breaking** (fix, mejora interna, nuevo input opcional).
  Al mergear, el tagger **mueve `vN`** al merge commit.
  ⚠️ Impacta a **todos** los consumidores `@vN` en su próximo run.
- **`release:major`** — cambio **breaking**: renombrar un check name (la clave `name:`
  raíz de un reusable), cambiar/eliminar/renombrar un input, o cualquier cambio de
  contrato. Al mergear, el tagger **crea `v(N+1)`** y deja `vN` quieto; los consumidores
  siguen en `vN` hasta migrar deliberadamente. **Ante la duda, usa `release:major`.**

Aplica la etiqueta al crear el PR:

```bash
gh pr create --label release:move    # o release:major
# o después:  gh pr edit <n> --add-label release:major
```

Sin la etiqueta, el check requerido **`Release label check`** deja el PR en rojo y
bloquea el merge.

**Si el PR no toca reusables** (docs, governance, manifest, scripts): no requiere
etiqueta; el gate pasa solo.

## Qué NO hacer

- **No muevas ni crees tags a mano** (`git tag` / `gh release` / `git push origin v*`).
  El tagging lo hace `release-reusables.yml` al mergear, según la etiqueta. La escotilla
  `workflow_dispatch` de ese workflow es solo para recuperación/bootstrap, no para uso
  rutinario.
- No renombres la clave `name:` raíz de un reusable sin tratarlo como `release:major`:
  es el check name que los consumidores marcan como required en sus Rulesets.
