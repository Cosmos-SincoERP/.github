#!/usr/bin/env bash
# lib-render.sh — funciones de render y de acceso remoto compartidas.
#
# Source-eada por sync-governance.sh, drift-check-governance.sh, scan-repo.sh
# y create-repo.sh. Consolida lógica que antes estaba duplicada:
#   - render_dependabot:  arma el dependabot.yml de un repo desde su template
#                         de stack + bloque docker derivado de overrides.
#   - fetch_remote_file:  lee un archivo de un repo de la org vía API.
#   - list_remote_workflows: lista los workflows de un repo de la org.
#   - emit_manifest_entry: imprime el bloque YAML de una entrada del manifest.
#
# Convención: stdout = resultado; mensajes informativos a stderr.
# Las funciones no clonan ni escriben; son puras respecto al filesystem local.
#
# Source-eable: este archivo no se ejecuta directamente.

# Renderiza un template de dependabot con sustitución de tokens y, opcionalmente,
# appendea un bloque docker con N directorios.
#   $1 = stack (dotnet | node-bun | terraform | github-actions)
#   $2 = terraform_directory (default "/")
#   $3 = docker_dirs_csv (paths separados por coma; vacío = sin bloque docker)
#   stdout = contenido del dependabot.yml
#   return = 1 (sin stdout) si el template del stack no existe
render_dependabot() {
  local stack="$1"
  local terraform_directory="${2:-/}"
  local docker_dirs_csv="${3:-}"
  local template="${TEMPLATES_DIR:-docs/templates}/dependabot-$stack.yml"

  if [ ! -f "$template" ]; then
    echo "render_dependabot: template no encontrado: $template (stack=$stack)" >&2
    return 1
  fi

  # Render base. Delimitador `#` (no `|`) porque el patrón contiene un `|` literal.
  sed "s#{{ terraform_directory | default('/') }}#$terraform_directory#g" "$template"

  # Appendear bloque docker si hay docker_directories en overrides del manifest.
  # Una sola entrada con `directories:` plural (Dependabot lo soporta desde 2024;
  # más limpio que N entradas separadas).
  if [ -n "$docker_dirs_csv" ]; then
    printf '\n'
    printf '  - package-ecosystem: "docker"\n'
    printf '    directories:\n'
    IFS=',' read -ra DOCKER_DIRS <<< "$docker_dirs_csv"
    for d in "${DOCKER_DIRS[@]}"; do
      printf '      - "%s"\n' "$d"
    done
    printf '    schedule:\n'
    printf '      interval: "weekly"\n'
    printf '      day: "wednesday"\n'
    printf '    open-pull-requests-limit: 5\n'
    printf '    groups:\n'
    printf '      all:\n'
    printf '        applies-to: version-updates\n'
    printf '        patterns: ["*"]\n'
  fi
}

# Obtiene el contenido actual de un archivo en un repo destino.
#   $1 = owner/repo, $2 = path
#   stdout = contenido (vacío si no existe)
fetch_remote_file() {
  local owner_repo="$1" path="$2"
  gh api "repos/$owner_repo/contents/$path" --jq '.content' 2>/dev/null \
    | base64 -d 2>/dev/null || true
}

# Lista los workflow files (.yml/.yaml) de un repo destino.
#   $1 = owner/repo
list_remote_workflows() {
  local owner_repo="$1"
  gh api "repos/$owner_repo/contents/.github/workflows" \
    --jq '.[] | select(.type=="file") | select(.name | test("\\.(yml|yaml)$")) | .name' \
    2>/dev/null || true
}

# Imprime el bloque YAML de una entrada del manifest (indentación de `repos:`).
#   $1 = name
#   $2 = stack
#   $3 = consumes_csv     (default "reusables,dependabot")
#   $4 = terraform_dir    (vacío = sin override)
#   $5 = docker_dirs_csv  (vacío = sin override)
#   $6 = stack_suffix     (opcional; ej. "# inferido")
emit_manifest_entry() {
  local name="$1" stack="$2"
  local consumes_csv="${3:-reusables,dependabot}"
  local terraform_dir="${4:-}" docker_dirs_csv="${5:-}" stack_suffix="${6:-}"

  local consumes_yaml="${consumes_csv//,/, }"

  printf '  - name: %s\n' "$name"
  if [ -n "$stack_suffix" ]; then
    printf '    stack: %s  %s\n' "$stack" "$stack_suffix"
  else
    printf '    stack: %s\n' "$stack"
  fi
  printf '    consumes: [%s]\n' "$consumes_yaml"

  if [ -n "$terraform_dir" ] || [ -n "$docker_dirs_csv" ]; then
    printf '    overrides:\n'
    if [ -n "$terraform_dir" ]; then
      printf '      terraform_directory: %s\n' "$terraform_dir"
    fi
    if [ -n "$docker_dirs_csv" ]; then
      printf '      docker_directories:\n'
      local d
      IFS=',' read -ra _MANIFEST_DOCKER_DIRS <<< "$docker_dirs_csv"
      for d in "${_MANIFEST_DOCKER_DIRS[@]}"; do
        printf '        - %s\n' "$d"
      done
    fi
  fi
}
