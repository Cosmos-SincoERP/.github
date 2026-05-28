#!/usr/bin/env bash
# lib-scan.sh — funciones de inspección de repos.
#
# Compartido entre scan-repo.sh (sugerencia de manifest) y
# drift-check-governance.sh (detección de overrides desactualizados).
#
# Diseño en dos niveles para no duplicar heurísticas:
#   - Núcleo `paths_*`: recibe por stdin una LISTA DE PATHS de archivos
#     (relativos a la raíz del repo, sin leading slash) y aplica las
#     heurísticas. No toca el filesystem ni la red.
#   - Wrappers `scan_*`: operan sobre un directorio ya clonado, derivando
#     la lista de paths con `find` y delegando en el núcleo.
#
# Esto permite alimentar las mismas heurísticas desde un clone local (find)
# o desde la API de árboles de GitHub (ver api_repo_file_paths en lib-render.sh),
# evitando falsos negativos por clones parciales/incompletos en CI.
#
# La semántica de `find -maxdepth N` se replica filtrando por número de
# componentes del path: un path con N componentes ⇔ profundidad N bajo la raíz.
#
# IMPORTANTE (SIGPIPE/pipefail): NO usar `... | grep -q` en un pipeline vivo.
# Con `set -o pipefail`, `grep -q` cierra el pipe al primer match y el upstream
# recibe SIGPIPE (141), lo que marca el pipeline como fallido AUNQUE haya match.
# El patrón seguro es capturar a variable y testear con `[ -n ]`, neutralizando
# el exit-1 de `grep` (sin match) con `|| true`.
#
# Convención: imprimen resultado en stdout, errores informativos a stderr.
# Source-eable: este archivo no se ejecuta directamente.

# ── Núcleo: heurísticas sobre lista de paths (stdin) ───────────────

# Filtra stdin dejando paths con <= $1 componentes (equivale a find -maxdepth $1).
_paths_maxdepth() { awk -v md="$1" -F/ 'NF>=1 && NF<=md'; }

# ¿Existe algún path que matchee, dentro de profundidad y excluyendo opcional?
#   $1 = maxdepth, $2 = name_regex (ERE), $3 = exclude_regex (ERE, opcional)
#   stdin = paths; return 0 si hay al menos un match, 1 si no.
_paths_match() {
  local maxd="$1" name_re="$2" exclude_re="${3:-}" out
  out="$(_paths_maxdepth "$maxd" | grep -E "$name_re" 2>/dev/null || true)"
  if [ -n "$exclude_re" ] && [ -n "$out" ]; then
    out="$(printf '%s\n' "$out" | grep -vE "$exclude_re" 2>/dev/null || true)"
  fi
  [ -n "$out" ]
}

# Infiere stack a partir de la lista de paths. Primera coincidencia gana.
#   stdin = paths; stdout = uno de: dotnet | node-bun | terraform | github-actions
paths_detect_stack() {
  local paths; paths="$(cat)"
  if printf '%s\n' "$paths" | _paths_match 5 '\.(csproj|sln)$' '(^|/)node_modules/'; then
    echo "dotnet"
  elif printf '%s\n' "$paths" | _paths_match 5 '(^|/)package\.json$' '(^|/)node_modules/'; then
    echo "node-bun"
  elif printf '%s\n' "$paths" | _paths_match 5 '\.tf$' '(^|/)\.terraform/'; then
    echo "terraform"
  else
    echo "github-actions"
  fi
}

# Verifica si existe el marker propio del stack declarado.
#   $1 = stack declarado; stdin = paths
#   exit 0 si el marker existe (o stack=github-actions = baseline siempre OK)
#   exit 1 si no existe (drift)
paths_stack_marker_exists() {
  local stack="$1"; local paths; paths="$(cat)"
  case "$stack" in
    dotnet)
      printf '%s\n' "$paths" | _paths_match 5 '\.(csproj|sln)$' '(^|/)node_modules/' ;;
    node-bun)
      printf '%s\n' "$paths" | _paths_match 5 '(^|/)package\.json$' '(^|/)node_modules/' ;;
    terraform)
      printf '%s\n' "$paths" | _paths_match 5 '\.tf$' '(^|/)\.terraform/' ;;
    github-actions)
      return 0 ;;  # baseline; no marker requerido
    *)
      return 0 ;;  # stack desconocido; no flagear
  esac
}

# Detecta directorios con Dockerfile. Stdout: una línea por dir, prefijo /,
# deduplicado y ordenado. Vacío (y exit 0) si no hay Dockerfiles.
#   stdin = paths
paths_detect_docker_dirs() {
  local matches
  matches="$(_paths_maxdepth 6 | grep -E '(^|/)Dockerfile$' 2>/dev/null | grep -vE '(^|/)node_modules/' 2>/dev/null || true)"
  [ -z "$matches" ] && return 0
  printf '%s\n' "$matches" \
    | while IFS= read -r f; do
        [ -z "$f" ] && continue
        d="$(dirname "$f")"
        if [ "$d" = "." ]; then
          echo "/"
        else
          echo "/$d"
        fi
      done \
    | sort -u
}

# Detecta terraform_directory según convención del manifest:
#   - *.tf en raíz                → vacío (default "/", sin override)
#   - infra/*.tf existe           → /infra
#   - otro layout                 → "UNKNOWN"
#   stdin = paths
paths_detect_terraform_dir() {
  local paths root infra
  paths="$(cat)"
  root="$(printf '%s\n' "$paths" | grep -E '^[^/]+\.tf$' 2>/dev/null || true)"
  infra="$(printf '%s\n' "$paths" | grep -E '^infra/[^/]+\.tf$' 2>/dev/null || true)"
  if [ -n "$root" ]; then
    echo ""
  elif [ -n "$infra" ]; then
    echo "/infra"
  else
    echo "UNKNOWN"
  fi
}

# ── Wrappers sobre un directorio clonado ───────────────────────────

# Lista los archivos de un directorio como paths relativos sin leading slash.
# Excluye .git/ para alinear con lo que devuelve la API de árboles.
#   $1 = dir raíz
_dir_paths() {
  local dir="$1"
  find "$dir" -type f -not -path '*/.git/*' 2>/dev/null \
    | while IFS= read -r f; do
        printf '%s\n' "${f#"$dir"/}"
      done
}

scan_detect_stack()         { _dir_paths "$1" | paths_detect_stack; }
scan_detect_docker_dirs()   { _dir_paths "$1" | paths_detect_docker_dirs; }
scan_detect_terraform_dir() { _dir_paths "$1" | paths_detect_terraform_dir; }
scan_stack_marker_exists()  { _dir_paths "$1" | paths_stack_marker_exists "$2"; }
