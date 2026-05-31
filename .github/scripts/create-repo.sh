#!/usr/bin/env bash
# create-repo.sh — creación de repos gobernados.
# Invocado por .github/workflows/create-repo.yml. Ver ADR 0004 y ADR 0005.
#
# Crea un repo nuevo en la org, le aplica los settings que el ruleset org no cubre,
# le scaffoldea el baseline de seguridad (security-checks.yml), hace el commit inicial de
# `main` (la App es bypass actor del ruleset org) y registra la entrada en el manifest de
# `.github` vía PR. Idempotente: re-correr tras un fallo parcial continúa.
#
# Este flujo NO crea CI/CD de negocio ni de devops (build/deploy/nuget/terraform): el
# repo nace solo con el baseline de seguridad. El resto del CI/CD lo añaden las skills de
# onboarding o el equipo cuando el código aterriza. Ver ADR 0005.
#
# Variables de entorno:
#   GH_TOKEN   — token de la App (Administration org+repo, Contents, Workflows, PRs)
#   REPO_NAME  — nombre del repo nuevo (sin owner)
#   DRY_RUN    — "true" (default): valida y muestra el plan sin crear nada
#   RUN_SHA    — SHA del commit de .github que disparó el flujo (para nombres)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-render.sh
source "$SCRIPT_DIR/lib-render.sh"

# ─── Config ──────────────────────────────────────────────────────────────────
ORG="Cosmos-SincoERP"
SELF_REPO="$ORG/.github"
MANIFEST="docs/repos-manifest.yml"
TEMPLATES_DIR="docs/templates"
RULESET_NAME="cosmos-baseline-checks"
WORK_DIR="/tmp/create-repo-work"

# Baseline único para todo repo nuevo (no hay arquetipos: ver ADR 0005).
#   STACK=github-actions — el repo nace con el dependabot de github-actions; cuando el
#   equipo aterriza su código y actualiza el manifest, el sync re-renderiza el dependabot
#   del stack real. REQUIRED_CHECKS — los checks de seguridad del security-checks.yml
#   gestionado (formato `<job-caller> / <job-del-reusable>`); son los únicos required que
#   aplica la creación.
STACK="github-actions"
REQUIRED_CHECKS=("dependency-review / trivy" "secret-scan / trufflehog")

REPO_NAME="${REPO_NAME:-}"
VISIBILITY="private"
DRY_RUN="${DRY_RUN:-true}"
RUN_SHA="${RUN_SHA:-manual}"

OWNER_REPO="$ORG/$REPO_NAME"
BRANCH="chore/onboard-$REPO_NAME"

# ─── Utilidades ──────────────────────────────────────────────────────────────
log()    { echo "[$(date +%H:%M:%S)] $*"; }
fail()   { log "ERROR: $*" >&2; }
section(){ echo; echo "═══ $* ═══"; }
die()    { fail "$*"; exit 1; }

declare -a SUMMARY=()
add_summary() { SUMMARY+=("$*"); }

# ─── Validación ──────────────────────────────────────────────────────────────
validate() {
  section "Validación"

  [ -n "$REPO_NAME" ] || die "REPO_NAME vacío."
  [[ "$REPO_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || die "REPO_NAME inválido: '$REPO_NAME' (solo [A-Za-z0-9._-])."

  log "REPO_NAME=$REPO_NAME  STACK=$STACK (baseline)  VISIBILITY=$VISIBILITY"
}

# ─── Render del scaffold a un workdir local ──────────────────────────────────
render_scaffold() {
  section "Render del scaffold (baseline de seguridad)"

  SCAFFOLD_DIR="$WORK_DIR/scaffold"
  rm -rf "$SCAFFOLD_DIR"; mkdir -p "$SCAFFOLD_DIR"

  # dependabot.yml: NO se renderiza al crear. Lo gestiona el sync/drift de gobernanza
  # (sync-governance.sh, keyed en `consumes`/`stack` del manifest) — se coloca en la
  # primera corrida del sync que dispara el merge del PR de manifest. Ver ADR 0005.

  # security-checks.yml (gestionado; idéntico al template del sync). Es el único artefacto
  # que scaffoldea la creación: baseline + seguridad, nada de CI/CD. Ver ADR 0005.
  mkdir -p "$SCAFFOLD_DIR/.github/workflows"
  cp "$TEMPLATES_DIR/security-checks.yml" "$SCAFFOLD_DIR/.github/workflows/security-checks.yml"
  log "  + .github/workflows/security-checks.yml"
}

# ─── Crear repo + settings ───────────────────────────────────────────────────
create_and_configure_repo() {
  section "Crear repo + settings"

  if gh api "repos/$OWNER_REPO" --jq '.name' >/dev/null 2>&1; then
    log "Repo $OWNER_REPO ya existe — saltando creación (idempotente)."
  else
    if [ "$DRY_RUN" = "true" ]; then
      log "DRY-RUN: crearía $OWNER_REPO ($VISIBILITY)."
    else
      gh repo create "$OWNER_REPO" "--$VISIBILITY" \
        || die "gh repo create falló (¿la App tiene Administration:write en la org?)."
      log "Repo creado: $OWNER_REPO"
      add_summary "Repo \`$OWNER_REPO\` creado ($VISIBILITY)."
    fi
  fi

  # Settings que el ruleset org NO cubre: squash-only + auto-merge + auto-delete.
  if [ "$DRY_RUN" = "true" ]; then
    log "DRY-RUN: aplicaría squash-only, auto-merge y delete-branch-on-merge."
  else
    gh api -X PATCH "repos/$OWNER_REPO" \
      -F allow_squash_merge=true \
      -F allow_merge_commit=false \
      -F allow_rebase_merge=false \
      -F delete_branch_on_merge=true \
      -F allow_auto_merge=true >/dev/null \
      || fail "No se pudieron aplicar todos los settings (¿Administration:write en el repo?)."
    log "Settings aplicados: squash-only, auto-merge, delete-branch-on-merge."
    add_summary "Settings: squash-only + auto-merge + auto-delete branch."
  fi
}

# ─── Commit inicial de main (App como bypass actor) ──────────────────────────
push_initial_main() {
  section "Commit inicial de main (bypass actor)"

  if [ "$DRY_RUN" = "true" ]; then
    log "DRY-RUN: pushearía el scaffold a main de $OWNER_REPO."
    return 0
  fi

  local clone_dir="$WORK_DIR/clone"
  rm -rf "$clone_dir"
  git clone --quiet "https://x-access-token:$GH_TOKEN@github.com/$OWNER_REPO.git" "$clone_dir" \
    || die "No se pudo clonar el repo recién creado."

  # Idempotencia: si el repo ya tiene commits (main bootstrapeado), no re-sembrar.
  # Más robusto que `git ls-remote --heads ... main`, que con --exit-code no siempre
  # detecta el ref vía el transporte autenticado.
  if git -C "$clone_dir" rev-parse --verify HEAD >/dev/null 2>&1; then
    log "main ya tiene contenido en $OWNER_REPO — saltando commit inicial (idempotente)."
    return 0
  fi

  ( cd "$clone_dir"
    git config user.email "governance-sync@cosmos-sincoerp.local"
    git config user.name "cosmos-governance-sync[bot]"
    git checkout -b main
    cp -r "$SCAFFOLD_DIR/." .
    git add -A
    git commit -q -m "chore: scaffold inicial (baseline de seguridad)"
    # La App debe estar en la bypass list del ruleset org (~DEFAULT_BRANCH).
    git push -q origin main \
      || die "push a main rechazado. ¿La App está en la bypass list del ruleset org B.1?"
  )
  log "Scaffold pusheado a main de $OWNER_REPO."
  add_summary "main inicializado con el baseline de seguridad."
}

# ─── Registrar en el manifest vía PR en .github ──────────────────────────────
register_in_manifest() {
  section "Registrar en el manifest (PR en $SELF_REPO)"

  # ¿Ya está en el manifest (repos: o skip:)? Here-string en vez de `yq | grep -q`:
  # con `set -o pipefail`, grep -q corta el pipe y yq muere con SIGPIPE (141), lo que
  # haría fallar el pipeline aunque el match exista.
  local known_names
  known_names="$(yq -r '.repos[].name, .skip[].name' "$MANIFEST")"
  if grep -qxF "$REPO_NAME" <<< "$known_names"; then
    log "$REPO_NAME ya está en el manifest — saltando (idempotente)."
    return 0
  fi

  local entry
  entry="$(emit_manifest_entry "$REPO_NAME" "$STACK")"
  entry="  # creado por create-repo (baseline)"$'\n'"$entry"

  if [ "$DRY_RUN" = "true" ]; then
    log "DRY-RUN: añadiría al manifest la entrada:"
    printf '%s\n' "$entry" | sed 's/^/      /'
    return 0
  fi

  # Insertar el bloque justo después de la línea `repos:`. Con head/tail (no awk -v,
  # que no es portable con newlines embebidos) para preservar comentarios.
  local repos_line new_manifest="$WORK_DIR/repos-manifest.yml"
  repos_line="$(grep -n '^repos:[[:space:]]*$' "$MANIFEST" | head -n1 | cut -d: -f1)"
  [ -n "$repos_line" ] || die "No se encontró la línea 'repos:' en $MANIFEST."
  {
    head -n "$repos_line" "$MANIFEST"
    echo ""
    printf '%s\n' "$entry"
    tail -n +"$((repos_line + 1))" "$MANIFEST"
  } > "$new_manifest"
  cp "$new_manifest" "$MANIFEST"

  # Validar que el manifest sigue siendo YAML válido y contiene la entrada.
  # Here-string (no `yq | grep -q`) por el mismo motivo de SIGPIPE/pipefail de arriba.
  yq e '.' "$MANIFEST" >/dev/null || die "El manifest quedó inválido tras insertar la entrada."
  local repo_names_after
  repo_names_after="$(yq -r '.repos[].name' "$MANIFEST")"
  grep -qxF "$REPO_NAME" <<< "$repo_names_after" || die "La entrada no quedó en repos:."

  git config user.email "governance-sync@cosmos-sincoerp.local"
  git config user.name "cosmos-governance-sync[bot]"
  git checkout -B "$BRANCH"
  git add "$MANIFEST"
  git commit -q -m "chore(governance): onboard $REPO_NAME al manifest"
  # Push a `origin` (este repo, .github): el checkout ya está autenticado como la App
  # (token: en create-repo.yml), así que no hace falta URL con token embebido — que
  # además sería sobreescrita por el http.extraheader que inyecta actions/checkout.
  git push -q --force-with-lease origin "HEAD:$BRANCH" \
    || die "No se pudo pushear la rama del manifest a $SELF_REPO."

  local existing_pr pr_body pr_number=""
  existing_pr="$(gh pr list --repo "$SELF_REPO" --head "$BRANCH" --state open --json number --jq '.[0].number' 2>/dev/null || echo "")"
  pr_body="$(cat <<EOF
Onboarding automático de \`$OWNER_REPO\` al manifest, generado por la creación de repos
(\`create-repo.yml\`) desde \`$SELF_REPO@${RUN_SHA:0:7}\`.

- **Stack**: \`$STACK\` (baseline; el sync ajusta el dependabot al stack real cuando el
  equipo actualiza el manifest)
- **Consume**: \`reusables, dependabot\`

El repo nació con el baseline de seguridad y sus settings; el CI/CD de negocio/devops se
añade aparte (skills de onboarding o a mano). Al mergear, el sync y el drift-check toman
este repo como gobernado. Tiene auto-merge habilitado: se mergea solo en cuanto los
checks pasen.

> Generado por create-repo.yml — ver ADR 0005.
EOF
)"

  if [ -n "$existing_pr" ]; then
    gh pr edit "$existing_pr" --repo "$SELF_REPO" --body "$pr_body" >/dev/null || true
    pr_number="$existing_pr"
    log "PR de manifest ya existe (#$existing_pr) — actualizado."
  else
    gh label create "governance-sync" --repo "$SELF_REPO" \
      --color "0e8a16" --description "PR generado por la gobernanza" >/dev/null 2>&1 || true
    local out
    if out="$(gh pr create --repo "$SELF_REPO" --base main --head "$BRANCH" \
        --title "chore(governance): onboard $REPO_NAME" \
        --body "$pr_body" --label "governance-sync" 2>&1)"; then
      log "PR de manifest abierto: $out"
      pr_number="$(gh pr list --repo "$SELF_REPO" --head "$BRANCH" --state open --json number --jq '.[0].number' 2>/dev/null || echo "")"
    else
      fail "gh pr create falló:"; printf '%s\n' "$out" | sed 's/^/      /'
      return 0
    fi
  fi

  # Habilitar auto-merge: con 0 approvals (B.2) + checks verdes, el PR se mergea solo.
  # No commit directo a .github: la App no es bypass de este repo (ADR 0004).
  if [ -n "$pr_number" ]; then
    if gh pr merge "$pr_number" --repo "$SELF_REPO" --auto --squash >/dev/null 2>&1; then
      log "Auto-merge habilitado en el PR de manifest #$pr_number."
      add_summary "PR de manifest #$pr_number (auto-merge habilitado)."
    else
      log "⚠ No se pudo habilitar auto-merge en #$pr_number — mergear manualmente."
      add_summary "PR de manifest #$pr_number abierto (auto-merge no disponible; mergear manual)."
    fi
  fi
}

# ─── Required status checks (repo-level ruleset) ─────────────────────────────
apply_required_checks() {
  section "Required status checks (ruleset $RULESET_NAME)"

  # Checks baseline de seguridad (constantes; ya no se derivan de un arquetipo). Ver ADR 0005.
  local checks_json payload
  checks_json="$(jq -nc --args '[$ARGS.positional[] | {context: .}]' "${REQUIRED_CHECKS[@]}")"

  payload="$(jq -n --arg name "$RULESET_NAME" --argjson checks "$checks_json" '{
    name: $name,
    target: "branch",
    enforcement: "active",
    conditions: { ref_name: { include: ["~DEFAULT_BRANCH"], exclude: [] } },
    rules: [ { type: "required_status_checks", parameters: {
      strict_required_status_checks_policy: false,
      required_status_checks: $checks } } ]
  }')"

  if [ "$DRY_RUN" = "true" ]; then
    log "DRY-RUN: crearía/actualizaría el ruleset con checks:"
    echo "$checks_json" | jq -r '.[].context' | sed 's/^/      - /'
    return 0
  fi

  # `first // empty` en el propio jq evita un `| head -n1` que daría SIGPIPE bajo pipefail.
  local existing_id
  existing_id="$(gh api "repos/$OWNER_REPO/rulesets" \
    --jq "[.[] | select(.name==\"$RULESET_NAME\") | .id] | first // empty" 2>/dev/null || echo "")"

  if [ -n "$existing_id" ]; then
    if echo "$payload" | gh api -X PUT "repos/$OWNER_REPO/rulesets/$existing_id" --input - >/dev/null 2>&1; then
      log "Ruleset $RULESET_NAME actualizado (#$existing_id)."
      add_summary "Required checks: ruleset actualizado."
    else
      fail "No se pudo actualizar el ruleset (best-effort, repo igual queda creado)."
    fi
  else
    if echo "$payload" | gh api -X POST "repos/$OWNER_REPO/rulesets" --input - >/dev/null 2>&1; then
      log "Ruleset $RULESET_NAME creado."
      add_summary "Required checks: ruleset creado."
    else
      fail "No se pudo crear el ruleset (best-effort, repo igual queda creado)."
    fi
  fi

  log "⚠ Verificar tras el primer PR que los nombres de check calzan; si no, ajustar el security-checks.yml/ruleset."
}

# ─── Resumen ─────────────────────────────────────────────────────────────────
emit_step_summary() {
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] || return 0
  {
    echo "# Creación de \`$REPO_NAME\`"
    echo
    echo "- Baseline de seguridad (stack \`$STACK\`)"
    echo "- Visibilidad: **$VISIBILITY**"
    echo
    if [ "$DRY_RUN" = "true" ]; then
      echo "> ⚠️ DRY-RUN — no se creó ni modificó nada. Repetir con \`dry_run: false\` para ejecutar."
      echo
      echo "## Archivos que se scaffoldearían"
      ( cd "$SCAFFOLD_DIR" && find . -type f | sort | sed 's#^\./#- `#; s#$#`#' )
    else
      echo "## Acciones"
      if [ ${#SUMMARY[@]} -gt 0 ]; then printf -- '- %s\n' "${SUMMARY[@]}"; else echo "- (sin cambios)"; fi
    fi
  } >> "$GITHUB_STEP_SUMMARY"
}

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
  [ -f "$MANIFEST" ] || die "Manifest no encontrado: $MANIFEST (¿se corre desde el root de .github?)."
  rm -rf "$WORK_DIR"; mkdir -p "$WORK_DIR"

  log "DRY_RUN=$DRY_RUN"

  validate
  render_scaffold
  create_and_configure_repo
  push_initial_main
  register_in_manifest
  apply_required_checks
  emit_step_summary

  section "Listo"
  if [ "$DRY_RUN" = "true" ]; then
    log "DRY-RUN completado (nada creado)."
  else
    log "Creación de $OWNER_REPO completada."
  fi
}

main "$@"
