#!/usr/bin/env bash
# Drift check: verifica alineación de repos consumidores con el manifest.
# Reporta hallazgos en una issue actualizable en este repo (SELF_REPO).
#
# No modifica nada en repos consumidores — read-only.

set -euo pipefail

ORG="Cosmos-SincoERP"
SELF_REPO="${SELF_REPO:-$ORG/.github}"
OLD_REUSABLES="$ORG/Cosmos.PlatformWorkflows"
MANIFEST="docs/repos-manifest.yml"
TEMPLATES_DIR="docs/templates"
ISSUE_LABEL="governance-drift-report"
ISSUE_TITLE_PREFIX="Governance drift report"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-scan.sh
source "$SCRIPT_DIR/lib-scan.sh"
# shellcheck source=lib-render.sh
source "$SCRIPT_DIR/lib-render.sh"

log() { echo "[$(date +%H:%M:%S)] $*"; }

# render_dependabot, fetch_remote_file y list_remote_workflows viven en
# lib-render.sh (source-eada arriba), compartidas con sync y create-repo.

# Drift findings — acumulan líneas markdown
declare -a DRIFT_DEPENDABOT=()
declare -a DRIFT_SECURITY_CHECKS=()
declare -a DRIFT_REUSABLES_STALE=()
declare -a DRIFT_ORPHAN_REPOS=()
declare -a DRIFT_OVERRIDES=()

check_repo() {
  local name="$1" stack="$2" consumes="$3" terraform_directory="$4" docker_dirs_csv="${5:-}"
  local owner_repo="$ORG/$name"

  log "Checking $owner_repo"

  if ! gh api "repos/$owner_repo" --jq '.name' >/dev/null 2>&1; then
    log "  ⚠ inaccesible, skip"
    return 0
  fi

  # 1. dependabot drift
  if [[ ",$consumes," == *,dependabot,* ]]; then
    local desired current
    desired="$(render_dependabot "$stack" "$terraform_directory" "$docker_dirs_csv" || true)"
    current="$(fetch_remote_file "$owner_repo" ".github/dependabot.yml")"
    if [ -n "$desired" ] && [ "$desired" != "$current" ]; then
      DRIFT_DEPENDABOT+=("- [\`$owner_repo\`](https://github.com/$owner_repo/blob/main/.github/dependabot.yml) — drift detectado (stack=\`$stack\`)")
    fi
  fi

  # 2. security-checks.yml drift
  if [[ ",$consumes," == *,reusables,* ]]; then
    local desired_sec current_sec
    desired_sec="$(cat "$TEMPLATES_DIR/security-checks.yml" 2>/dev/null || true)"
    current_sec="$(fetch_remote_file "$owner_repo" ".github/workflows/security-checks.yml")"
    if [ -n "$desired_sec" ] && [ "$desired_sec" != "$current_sec" ]; then
      if [ -z "$current_sec" ]; then
        DRIFT_SECURITY_CHECKS+=("- [\`$owner_repo\`](https://github.com/$owner_repo) — falta \`.github/workflows/security-checks.yml\`")
      else
        DRIFT_SECURITY_CHECKS+=("- [\`$owner_repo/.github/workflows/security-checks.yml\`](https://github.com/$owner_repo/blob/main/.github/workflows/security-checks.yml) — drift contra template")
      fi
    fi
  fi

  # 3. uses: residuales al repo viejo
  if [[ ",$consumes," == *,reusables,* ]]; then
    local workflows
    workflows="$(list_remote_workflows "$owner_repo")"
    while IFS= read -r wf; do
      [ -z "$wf" ] && continue
      local content
      content="$(fetch_remote_file "$owner_repo" ".github/workflows/$wf")"
      if echo "$content" | grep -q "$OLD_REUSABLES/.github/workflows/"; then
        DRIFT_REUSABLES_STALE+=("- [\`$owner_repo/.github/workflows/$wf\`](https://github.com/$owner_repo/blob/main/.github/workflows/$wf) — referencia stale al repo viejo")
      fi
    done <<< "$workflows"
  fi
}

# Detecta repos en la org que no están en manifest ni en skip
check_orphans() {
  local manifest_names skip_names
  manifest_names="$(yq eval '.repos[].name' "$MANIFEST" | sort -u)"
  skip_names="$(yq eval '.skip[].name' "$MANIFEST" | sort -u)"
  local known_names
  known_names="$(printf '%s\n%s\n' "$manifest_names" "$skip_names" | sort -u)"

  local org_repos
  org_repos="$(gh repo list "$ORG" --limit 200 --json name,isArchived \
    --jq '.[] | select(.isArchived | not) | .name' 2>/dev/null | sort -u)"

  while IFS= read -r repo; do
    [ -z "$repo" ] && continue
    if ! grep -qxF "$repo" <<< "$known_names"; then
      # Excluir el propio repo .github
      if [ "$repo" != ".github" ]; then
        DRIFT_ORPHAN_REPOS+=("- \`$ORG/$repo\` — no aparece en manifest ni en skip")
      fi
    fi
  done <<< "$org_repos"
}

# Diff de docker_directories. Imprime líneas markdown con `+`/`-`.
diff_docker_dirs() {
  local declared="$1" detected="$2"
  local declared_lines detected_lines d
  declared_lines="$(echo "$declared" | tr ',' '\n' | grep -v '^$' | sort -u || true)"
  detected_lines="$(echo "$detected" | tr ',' '\n' | grep -v '^$' | sort -u || true)"

  while IFS= read -r d; do
    [ -z "$d" ] && continue
    if ! echo "$declared_lines" | grep -qxF "$d"; then
      echo "    - \`+ $d\` (en repo, no declarado)"
    fi
  done <<< "$detected_lines"

  while IFS= read -r d; do
    [ -z "$d" ] && continue
    if ! echo "$detected_lines" | grep -qxF "$d"; then
      echo "    - \`- $d\` (declarado, no en repo)"
    fi
  done <<< "$declared_lines"
  return 0
}

# Detecta drift entre overrides declarados y estado real del repo.
check_overrides_drift() {
  local name="$1" declared_stack="$2" declared_tf="$3" declared_docker_csv="${4:-}"
  local owner_repo="$ORG/$name"

  # Lista de archivos del repo vía API de árboles (autoritativa, sin clone).
  local paths
  paths="$(api_repo_file_paths "$owner_repo")"
  # Repo vacío / inaccesible: nada que comparar.
  if [ -z "$paths" ]; then
    return 0
  fi

  local -a findings=()

  # 1. docker_directories
  local detected_docker_csv
  detected_docker_csv="$(printf '%s\n' "$paths" | paths_detect_docker_dirs | tr '\n' ',' | sed 's/,$//')"
  if [ "$detected_docker_csv" != "$declared_docker_csv" ]; then
    findings+=("  - **\`docker_directories\`** desactualizado:")
    local _diff_out
    _diff_out="$(diff_docker_dirs "$declared_docker_csv" "$detected_docker_csv")"
    while IFS= read -r line; do
      [ -n "$line" ] && findings+=("$line")
    done <<< "$_diff_out"
  fi

  # 2. terraform_directory (solo aplica a stack=terraform)
  if [ "$declared_stack" = "terraform" ]; then
    local detected_tf norm_declared_tf
    detected_tf="$(printf '%s\n' "$paths" | paths_detect_terraform_dir)"
    norm_declared_tf="$declared_tf"
    [ "$norm_declared_tf" = "/" ] && norm_declared_tf=""
    if [ "$detected_tf" = "UNKNOWN" ]; then
      findings+=("  - **\`terraform_directory\`** sin layout estándar: declarado \`${declared_tf:-/}\`, no hay \`.tf\` en raíz ni en \`/infra\`")
    elif [ "$detected_tf" != "$norm_declared_tf" ]; then
      findings+=("  - **\`terraform_directory\`** desactualizado: declarado \`${declared_tf:-/}\`, detectado \`${detected_tf:-/}\`")
    fi
  fi

  # 3. stack: marker del declarado no existe
  if ! printf '%s\n' "$paths" | paths_stack_marker_exists "$declared_stack"; then
    findings+=("  - **\`stack\`** sin marker: declarado \`$declared_stack\`, no se encontró archivo característico en el repo")
  fi

  if [ ${#findings[@]} -gt 0 ]; then
    local block="- \`$owner_repo\`"
    local line
    for line in "${findings[@]}"; do
      block="$block"$'\n'"$line"
    done
    DRIFT_OVERRIDES+=("$block")
  fi
}

build_report() {
  local total_drift=$((${#DRIFT_DEPENDABOT[@]} + ${#DRIFT_SECURITY_CHECKS[@]} + ${#DRIFT_REUSABLES_STALE[@]} + ${#DRIFT_ORPHAN_REPOS[@]} + ${#DRIFT_OVERRIDES[@]}))

  cat <<EOF
> Reporte automático generado por \`drift-check-governance.yml\` el $(date -u +'%Y-%m-%d %H:%M UTC').
> Total hallazgos: **$total_drift**.

## 1. Dependabot drift

Repos cuyo \`.github/dependabot.yml\` no coincide con el template gestionado.

EOF
  if [ ${#DRIFT_DEPENDABOT[@]} -eq 0 ]; then
    echo "_Sin drift._"
  else
    printf '%s\n' "${DRIFT_DEPENDABOT[@]}"
  fi

  cat <<EOF

## 2. Security-checks drift

Repos cuyo \`.github/workflows/security-checks.yml\` falta o no coincide con el template gestionado.

EOF
  if [ ${#DRIFT_SECURITY_CHECKS[@]} -eq 0 ]; then
    echo "_Sin drift._"
  else
    printf '%s\n' "${DRIFT_SECURITY_CHECKS[@]}"
  fi

  cat <<EOF

## 3. Referencias stale al repo viejo

Workflows que aún apuntan a \`$OLD_REUSABLES\` en vez de a \`$SELF_REPO\`.

EOF
  if [ ${#DRIFT_REUSABLES_STALE[@]} -eq 0 ]; then
    echo "_Sin referencias stale._"
  else
    printf '%s\n' "${DRIFT_REUSABLES_STALE[@]}"
  fi

  cat <<EOF

## 4. Repos sin clasificar

Repos en \`$ORG\` no archivados que no están en \`repos:\` ni en \`skip:\` del manifest.

EOF
  if [ ${#DRIFT_ORPHAN_REPOS[@]} -eq 0 ]; then
    echo "_Sin huérfanos._"
  else
    printf '%s\n' "${DRIFT_ORPHAN_REPOS[@]}"
  fi

  cat <<EOF

## 5. Manifest overrides desactualizados

Repos en \`repos:\` cuyos \`stack\`/\`overrides\` no coinciden con la estructura real del repo (Dockerfiles añadidos/movidos/eliminados, \`terraform_directory\` inválido, stack sin marker).

EOF
  if [ ${#DRIFT_OVERRIDES[@]} -eq 0 ]; then
    echo "_Sin drift en overrides._"
  else
    local entry
    for entry in "${DRIFT_OVERRIDES[@]}"; do
      printf '%s\n' "$entry"
    done
  fi

  cat <<EOF

---

**Cómo actuar:**
- Drift de dependabot: disparar \`sync-governance.yml\` (workflow_dispatch) o \`only=dependabot\`.
- Drift de security-checks: disparar sync con \`only=security-checks\`.
- Referencias stale: disparar sync con \`only=uses\`.
- Repos sin clasificar: añadirlos al manifest (\`repos:\` o \`skip:\` con \`reason:\`).
- Overrides desactualizados: correr \`bash .github/scripts/scan-repo.sh <repo>\` para ver el bloque sugerido y editar \`docs/repos-manifest.yml\`.
EOF
}

main() {
  log "Iniciando drift check ($SELF_REPO)"

  if [ ! -f "$MANIFEST" ]; then
    log "ERROR: manifest no encontrado: $MANIFEST"; exit 1
  fi

  local repos_json
  repos_json="$(yq eval -o=json '.repos' "$MANIFEST")"

  while IFS= read -r entry; do
    local name stack consumes td dd
    name="$(echo "$entry" | jq -r '.name')"
    stack="$(echo "$entry" | jq -r '.stack')"
    consumes="$(echo "$entry" | jq -r '.consumes | join(",")')"
    td="$(echo "$entry" | jq -r '.overrides.terraform_directory // "/"')"
    dd="$(echo "$entry" | jq -r '.overrides.docker_directories // [] | join(",")')"
    check_repo "$name" "$stack" "$consumes" "$td" "$dd"
    check_overrides_drift "$name" "$stack" "$td" "$dd"
  done < <(echo "$repos_json" | jq -c '.[]')

  check_orphans

  # Construir issue body
  local body
  body="$(build_report)"
  local title="$ISSUE_TITLE_PREFIX ($(date -u +'%Y-%m-%d'))"

  # Modo dry-run: solo imprime el body, no toca GitHub.
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "=== TITLE ==="
    echo "$title"
    echo "=== BODY ==="
    echo "$body"
    return 0
  fi

  # Asegurar label existe
  gh label create "$ISSUE_LABEL" --repo "$SELF_REPO" \
    --color "fbca04" --description "Reporte de drift del sync de gobernanza" \
    2>/dev/null || true

  # Buscar issue existente con la label (la primera abierta)
  local existing
  existing="$(gh issue list --repo "$SELF_REPO" --label "$ISSUE_LABEL" \
    --state open --limit 1 --json number --jq '.[0].number' 2>/dev/null || echo "")"

  if [ -n "$existing" ]; then
    gh issue edit "$existing" --repo "$SELF_REPO" \
      --title "$title" --body "$body" >/dev/null
    log "Issue #$existing actualizada en $SELF_REPO"
  else
    local url
    url="$(gh issue create --repo "$SELF_REPO" \
      --title "$title" --body "$body" --label "$ISSUE_LABEL" 2>&1 | tail -n1)"
    log "Issue creada: $url"
  fi

  # Step summary
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
      echo "# Drift check — resumen"
      echo
      echo "- Dependabot drift: **${#DRIFT_DEPENDABOT[@]}**"
      echo "- Security-checks drift: **${#DRIFT_SECURITY_CHECKS[@]}**"
      echo "- Reusables stale: **${#DRIFT_REUSABLES_STALE[@]}**"
      echo "- Repos huérfanos: **${#DRIFT_ORPHAN_REPOS[@]}**"
      echo "- Overrides desactualizados: **${#DRIFT_OVERRIDES[@]}**"
    } >> "$GITHUB_STEP_SUMMARY"
  fi
}

main "$@"
