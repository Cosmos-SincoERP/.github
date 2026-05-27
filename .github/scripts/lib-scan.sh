#!/usr/bin/env bash
# lib-scan.sh — funciones de inspección de repos.
#
# Compartido entre scan-repo.sh (sugerencia de manifest) y
# drift-check-governance.sh (detección de overrides desactualizados).
#
# Las funciones operan sobre un directorio ya clonado (no clonan).
# Convención: imprimen resultado en stdout, errores informativos a stderr.
#
# Source-eable: este archivo no se ejecuta directamente.

# Infiere stack a partir del contenido del repo. Primera coincidencia gana.
#   $1 = dir raíz del clone
#   stdout = uno de: dotnet | node-bun | terraform | github-actions
scan_detect_stack() {
  local dir="$1"
  if find "$dir" -maxdepth 5 \( -name '*.csproj' -o -name '*.sln' \) \
       -not -path '*/node_modules/*' 2>/dev/null | grep -q .; then
    echo "dotnet"
  elif find "$dir" -maxdepth 5 -name 'package.json' \
         -not -path '*/node_modules/*' 2>/dev/null | grep -q .; then
    echo "node-bun"
  elif find "$dir" -maxdepth 5 -name '*.tf' \
         -not -path '*/.terraform/*' 2>/dev/null | grep -q .; then
    echo "terraform"
  else
    echo "github-actions"
  fi
}

# Verifica si existe el marker propio del stack declarado en el repo.
#   $1 = dir, $2 = stack declarado
#   exit 0 si el marker existe (o stack=github-actions = baseline siempre OK)
#   exit 1 si no existe (drift)
scan_stack_marker_exists() {
  local dir="$1" stack="$2"
  case "$stack" in
    dotnet)
      find "$dir" -maxdepth 5 \( -name '*.csproj' -o -name '*.sln' \) \
        -not -path '*/node_modules/*' 2>/dev/null | grep -q .
      ;;
    node-bun)
      find "$dir" -maxdepth 5 -name 'package.json' \
        -not -path '*/node_modules/*' 2>/dev/null | grep -q .
      ;;
    terraform)
      find "$dir" -maxdepth 5 -name '*.tf' \
        -not -path '*/.terraform/*' 2>/dev/null | grep -q .
      ;;
    github-actions)
      return 0  # baseline; no marker requerido
      ;;
    *)
      return 0  # stack desconocido; no flagear
      ;;
  esac
}

# Detecta directorios con Dockerfile. Stdout: una línea por dir, prefijo /,
# deduplicado y ordenado. Vacío si no hay Dockerfiles.
#   $1 = dir
scan_detect_docker_dirs() {
  local dir="$1"
  find "$dir" -maxdepth 6 -name 'Dockerfile' \
    -not -path '*/node_modules/*' 2>/dev/null \
    | while IFS= read -r dockerfile; do
        [ -z "$dockerfile" ] && continue
        rel="${dockerfile#$dir}"
        d="$(dirname "$rel")"
        if [ -z "$d" ] || [ "$d" = "." ] || [ "$d" = "/" ]; then
          echo "/"
        else
          echo "$d"
        fi
      done \
    | sort -u
}

# Detecta terraform_directory según convención del manifest:
#   - *.tf en raíz                → vacío (default "/", sin override)
#   - infra/*.tf existe           → /infra
#   - otro layout                 → "UNKNOWN" + WARN a stderr
#   $1 = dir
scan_detect_terraform_dir() {
  local dir="$1"
  if ls "$dir"/*.tf >/dev/null 2>&1; then
    echo ""
  elif ls "$dir"/infra/*.tf >/dev/null 2>&1; then
    echo "/infra"
  else
    echo "UNKNOWN"
  fi
}
