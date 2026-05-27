#!/usr/bin/env bash
# Sync governance: propaga dependabot.yml y referencias `uses:` a repos consumidores.
# Invocado por .github/workflows/sync-governance.yml.
#
# Variables de entorno requeridas:
#   GH_TOKEN     — token con contents:write + pull-requests:write en los repos destino
#   SYNC_SHA     — SHA del commit en este repo que disparó el sync
#   DRY_RUN      — "true" para no abrir PRs (default false)
#   TARGET_REPO  — nombre de repo (sin owner) para filtrar; vacío = todos
#   ONLY         — all | dependabot | uses

set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────
ORG="Cosmos-SincoERP"
SELF_REPO="$ORG/.github"
OLD_REUSABLES="$ORG/Cosmos.PlatformWorkflows"
NEW_REUSABLES="$SELF_REPO"
MANIFEST="docs/repos-manifest.yml"
TEMPLATES_DIR="docs/templates"
BRANCH_NAME="chore/sync-governance-${SYNC_SHA:0:7}"
COMMIT_MSG_BASE="chore(governance): sync from $SELF_REPO@${SYNC_SHA:0:7}"
WORK_DIR="/tmp/sync-governance-work"

DRY_RUN="${DRY_RUN:-false}"
TARGET_REPO="${TARGET_REPO:-}"
ONLY="${ONLY:-all}"

# ─── Estadísticas ────────────────────────────────────────────────────────────
declare -i COUNT_PROCESSED=0
declare -i COUNT_PR_OPENED=0
declare -i COUNT_PR_UPDATED=0
declare -i COUNT_UP_TO_DATE=0
declare -i COUNT_FAILED=0
declare -a FAILED_REPOS=()

# ─── Funciones de utilidad ───────────────────────────────────────────────────

log()    { echo "[$(date +%H:%M:%S)] $*"; }
fail()   { log "ERROR: $*" >&2; }
section(){ echo; echo "═══ $* ═══"; }

# Renderiza un template de dependabot con sustitución de tokens.
# Args: stack, terraform_directory
render_dependabot() {
  local stack="$1"
  local terraform_directory="${2:-/}"
  local template="$TEMPLATES_DIR/dependabot-$stack.yml"

  if [ ! -f "$template" ]; then
    fail "Template no encontrado: $template (stack=$stack)"
    return 1
  fi

  # Sustitución del único token soportado por ahora.
  # Delimitador `#` (no `|`) porque el patrón contiene un `|` literal.
  sed "s#{{ terraform_directory | default('/') }}#$terraform_directory#g" "$template"
}

# Obtiene el contenido actual de un archivo en un repo destino.
# Args: owner/repo, path
# Output: contenido del archivo (vacío si no existe)
fetch_remote_file() {
  local owner_repo="$1" path="$2"
  gh api "repos/$owner_repo/contents/$path" --jq '.content' 2>/dev/null \
    | base64 -d 2>/dev/null || true
}

# Lista los workflow files (.yml/.yaml) del repo destino.
list_remote_workflows() {
  local owner_repo="$1"
  gh api "repos/$owner_repo/contents/.github/workflows" \
    --jq '.[] | select(.type=="file") | select(.name | test("\\.(yml|yaml)$")) | .name' \
    2>/dev/null || true
}

# ─── Lógica principal por repo ───────────────────────────────────────────────

# Procesa un repo: detecta cambios necesarios y aplica si !DRY_RUN.
# Args: name, stack, consumes (csv), terraform_directory
process_repo() {
  local name="$1" stack="$2" consumes="$3" terraform_directory="$4"
  local owner_repo="$ORG/$name"

  section "$owner_repo (stack=$stack, consumes=[$consumes])"

  # Verificar acceso al repo
  if ! gh api "repos/$owner_repo" --jq '.name' >/dev/null 2>&1; then
    fail "No accesible: $owner_repo (¿token con permisos? ¿repo existe?)"
    COUNT_FAILED+=1; FAILED_REPOS+=("$owner_repo (no accesible)")
    return 0
  fi

  local repo_workdir="$WORK_DIR/$name"
  rm -rf "$repo_workdir"
  mkdir -p "$repo_workdir"

  local has_changes=false
  local change_summary=()

  # ─ Cambio 1: dependabot.yml ──────────────────────────────────────────────
  if [[ ",$consumes," == *,dependabot,* ]] && [[ "$ONLY" == "all" || "$ONLY" == "dependabot" ]]; then
    local desired current
    desired="$(render_dependabot "$stack" "$terraform_directory")" || { COUNT_FAILED+=1; FAILED_REPOS+=("$owner_repo (template error)"); return 0; }
    current="$(fetch_remote_file "$owner_repo" ".github/dependabot.yml")"

    if [ "$desired" != "$current" ]; then
      mkdir -p "$repo_workdir/.github"
      echo "$desired" > "$repo_workdir/.github/dependabot.yml"
      has_changes=true
      change_summary+=("- \`.github/dependabot.yml\`: adopted managed template (stack=\`$stack\`)")
      log "  ✎ dependabot.yml difiere — marcado para cambio"
    else
      log "  ✓ dependabot.yml al día"
    fi
  fi

  # ─ Cambio 2: uses: en workflows ──────────────────────────────────────────
  if [[ ",$consumes," == *,reusables,* ]] && [[ "$ONLY" == "all" || "$ONLY" == "uses" ]]; then
    local workflows
    workflows="$(list_remote_workflows "$owner_repo")"

    while IFS= read -r wf; do
      [ -z "$wf" ] && continue
      local content updated
      content="$(fetch_remote_file "$owner_repo" ".github/workflows/$wf")"
      [ -z "$content" ] && continue

      # Reemplazo: Cosmos-SincoERP/Cosmos.PlatformWorkflows/ → Cosmos-SincoERP/.github/
      updated="$(echo "$content" | sed "s|$OLD_REUSABLES/.github/workflows/|$NEW_REUSABLES/.github/workflows/|g")"

      if [ "$content" != "$updated" ]; then
        mkdir -p "$repo_workdir/.github/workflows"
        echo "$updated" > "$repo_workdir/.github/workflows/$wf"
        has_changes=true
        change_summary+=("- \`.github/workflows/$wf\`: reusables path → \`$NEW_REUSABLES\`")
        log "  ✎ $wf difiere — marcado para cambio"
      fi
    done <<< "$workflows"
  fi

  # ─ Aplicar cambios ───────────────────────────────────────────────────────
  if ! $has_changes; then
    log "  → ya al día (sin cambios pendientes)"
    COUNT_UP_TO_DATE+=1
    COUNT_PROCESSED+=1
    return 0
  fi

  if [ "$DRY_RUN" = "true" ]; then
    log "  → DRY-RUN: ${#change_summary[@]} cambio(s) detectado(s), no se abre PR"
    for line in "${change_summary[@]}"; do log "      $line"; done
    COUNT_PROCESSED+=1
    return 0
  fi

  apply_changes "$owner_repo" "$repo_workdir" "${change_summary[@]}"
  COUNT_PROCESSED+=1
}

# Clona, escribe, commitea, pushea y abre/actualiza PR.
# Args: owner_repo, workdir, ...summary_lines
apply_changes() {
  local owner_repo="$1"; shift
  local workdir="$1"; shift
  local summary=("$@")

  local clone_dir="$workdir/.clone"
  rm -rf "$clone_dir"

  # Clone (depth 1 para velocidad; el bot solo necesita HEAD).
  # Captura output con stderr para reportar errores reales (no usar pipe
  # con grep porque genera falsos negativos cuando clone tiene éxito).
  local clone_log
  if ! clone_log="$(git clone --depth 1 --branch main \
        "https://x-access-token:$GH_TOKEN@github.com/$owner_repo.git" \
        "$clone_dir" 2>&1)"; then
    fail "Clone falló para $owner_repo:"
    printf '%s\n' "$clone_log" | sed 's/^/      /'
    COUNT_FAILED+=1; FAILED_REPOS+=("$owner_repo (clone failed)")
    return 0
  fi

  cd "$clone_dir"
  git config user.email "governance-sync@cosmos-sincoerp.local"
  git config user.name "cosmos-governance-sync[bot]"

  # Si la rama del bot ya existe en remoto, traerla; si no, crearla desde main
  if git ls-remote --exit-code --heads origin "$BRANCH_NAME" >/dev/null 2>&1; then
    git fetch --depth 1 origin "$BRANCH_NAME":"$BRANCH_NAME" || true
    git checkout "$BRANCH_NAME"
  else
    git checkout -b "$BRANCH_NAME"
  fi

  # Copiar archivos desde el workdir staged sobre el clone
  if [ -d "$workdir/.github" ]; then
    mkdir -p .github
    cp -r "$workdir/.github/." .github/
  fi

  git add -A
  if git diff --cached --quiet; then
    log "  → sin diff efectivo tras clone (cambios ya en main); skip"
    cd - >/dev/null
    return 0
  fi

  git commit -m "$COMMIT_MSG_BASE"

  if ! git push --force-with-lease origin "$BRANCH_NAME"; then
    fail "Push falló para $owner_repo"
    COUNT_FAILED+=1; FAILED_REPOS+=("$owner_repo (push failed)")
    cd - >/dev/null
    return 0
  fi

  # Crear o actualizar PR
  local pr_body
  pr_body="$(cat <<EOF
Sync automático de gobernanza desde [\`$SELF_REPO@${SYNC_SHA:0:7}\`](https://github.com/$SELF_REPO/commit/$SYNC_SHA).

## Cambios

$(printf '%s\n' "${summary[@]}")

## ¿Por qué?

Este repo es **gestionado** vía el sync workflow de \`$SELF_REPO\`. Cuando una plantilla o referencia cambia ahí, esta PR refleja el efecto sobre este repo.

## ¿Cómo proceder?

- Si los checks pasan: mergear (auto-merge si está habilitado).
- Si algo falla: ver logs del check; en caso de bug del sync, abrir issue en [\`$SELF_REPO\`](https://github.com/$SELF_REPO/issues).
- No editar este PR a mano — el sync lo regenerará.

> Generado por sync-governance.yml
EOF
)"

  local existing_pr
  existing_pr="$(gh pr list --repo "$owner_repo" --head "$BRANCH_NAME" --state open --json number --jq '.[0].number' 2>/dev/null || echo "")"

  if [ -n "$existing_pr" ]; then
    gh pr edit "$existing_pr" --repo "$owner_repo" --body "$pr_body" >/dev/null
    log "  ✓ PR #$existing_pr actualizado en $owner_repo"
    COUNT_PR_UPDATED+=1
  else
    # No usar --label aquí: si la label no existe en el repo destino, gh
    # aborta la creación entera (no solo la asignación de label). Crearla
    # primero y verificar el exit code de pr create real.
    gh label create "governance-sync" --repo "$owner_repo" \
      --color "0e8a16" --description "PR generado por el sync de gobernanza" \
      >/dev/null 2>&1 || true

    local pr_output
    if pr_output="$(gh pr create --repo "$owner_repo" \
        --base main --head "$BRANCH_NAME" \
        --title "$COMMIT_MSG_BASE" \
        --body "$pr_body" \
        --label "governance-sync" 2>&1)"; then
      log "  ✓ PR abierto: $pr_output"
      COUNT_PR_OPENED+=1
    else
      fail "PR create falló para $owner_repo:"
      printf '%s\n' "$pr_output" | sed 's/^/      /'
      COUNT_FAILED+=1; FAILED_REPOS+=("$owner_repo (PR create failed)")
    fi
  fi

  cd - >/dev/null
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
  if [ ! -f "$MANIFEST" ]; then
    fail "Manifest no encontrado: $MANIFEST"
    exit 1
  fi

  log "Configuración: DRY_RUN=$DRY_RUN, ONLY=$ONLY, TARGET_REPO=${TARGET_REPO:-<all>}"
  log "Templates dir: $TEMPLATES_DIR"
  log "Branch destino: $BRANCH_NAME"

  rm -rf "$WORK_DIR"
  mkdir -p "$WORK_DIR"

  # Parse manifest a JSON para iterar
  local repos_json
  repos_json="$(yq eval -o=json '.repos' "$MANIFEST")"

  local total
  total="$(echo "$repos_json" | jq 'length')"
  log "Manifest contiene $total repo(s) (sin skip:)"

  # Iterar (uso process substitution para no perder vars por subshell)
  while IFS= read -r entry; do
    local name stack consumes td
    name="$(echo "$entry" | jq -r '.name')"
    stack="$(echo "$entry" | jq -r '.stack')"
    consumes="$(echo "$entry" | jq -r '.consumes | join(",")')"
    td="$(echo "$entry" | jq -r '.overrides.terraform_directory // "/"')"

    if [ -n "$TARGET_REPO" ] && [ "$name" != "$TARGET_REPO" ]; then
      continue
    fi

    process_repo "$name" "$stack" "$consumes" "$td" || true
  done < <(echo "$repos_json" | jq -c '.[]')

  # Resumen
  section "Resumen"
  log "Procesados:    $COUNT_PROCESSED"
  log "Al día:        $COUNT_UP_TO_DATE"
  log "PRs abiertos:  $COUNT_PR_OPENED"
  log "PRs actualiz:  $COUNT_PR_UPDATED"
  log "Fallidos:      $COUNT_FAILED"
  if [ ${#FAILED_REPOS[@]} -gt 0 ]; then
    log "Detalles de fallidos:"
    for r in "${FAILED_REPOS[@]}"; do log "  - $r"; done
  fi

  # GitHub Actions step summary
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
      echo "# Sync governance — resumen"
      echo
      echo "- Procesados: **$COUNT_PROCESSED**"
      echo "- Al día: **$COUNT_UP_TO_DATE**"
      echo "- PRs abiertos: **$COUNT_PR_OPENED**"
      echo "- PRs actualizados: **$COUNT_PR_UPDATED**"
      echo "- Fallidos: **$COUNT_FAILED**"
      if [ "$DRY_RUN" = "true" ]; then
        echo
        echo "> ⚠️ DRY-RUN — no se abrieron PRs reales."
      fi
    } >> "$GITHUB_STEP_SUMMARY"
  fi

  # Exit code: si hay fallidos, no fail (no queremos romper el workflow por
  # un repo inaccesible). Pero exit != 0 si hubo configuración inválida.
  return 0
}

main "$@"
