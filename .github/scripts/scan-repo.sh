#!/usr/bin/env bash
# scan-repo.sh — escanea un repo de la org y propone su bloque de manifest.
#
# Uso: bash .github/scripts/scan-repo.sh <repo-name>
#
# Hace un clone shallow temporal del repo en Cosmos-SincoERP, infiere el stack
# y detecta overrides (docker_directories, terraform_directory). Imprime el
# bloque YAML listo para pegar en docs/repos-manifest.yml.
#
# Heurísticas de stack (primera coincidencia gana):
#   1. *.csproj / *.sln  → dotnet
#   2. package.json      → node-bun
#   3. *.tf              → terraform
#   4. (ninguno)         → github-actions   (baseline solo)
#
# Read-only: el clone se borra al terminar.

set -euo pipefail

ORG="${ORG:-Cosmos-SincoERP}"
REPO="${1:-}"

if [ -z "$REPO" ]; then
  echo "Uso: bash .github/scripts/scan-repo.sh <repo-name>" >&2
  exit 1
fi

WORKDIR="$(mktemp -d -t scan-repo-XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

CLONE_DIR="$WORKDIR/$REPO"

if ! git clone --quiet --depth 1 "https://github.com/$ORG/$REPO.git" "$CLONE_DIR" 2>"$WORKDIR/clone.err"; then
  echo "ERROR: no se pudo clonar $ORG/$REPO" >&2
  sed 's/^/  /' "$WORKDIR/clone.err" >&2
  exit 2
fi

cd "$CLONE_DIR"

# Repo vacío: clone --depth 1 deja solo .git/. Avisar y emitir baseline.
if [ -z "$(ls -A . 2>/dev/null | grep -v '^\.git$' || true)" ]; then
  echo "WARN: $ORG/$REPO está vacío (sin commits). Emitiendo baseline; revisar cuando tenga contenido." >&2
fi

# --- Inferir stack -----------------------------------------------------------
stack="github-actions"
if find . -maxdepth 5 \( -name '*.csproj' -o -name '*.sln' \) \
     -not -path '*/node_modules/*' 2>/dev/null | grep -q .; then
  stack="dotnet"
elif find . -maxdepth 5 -name 'package.json' \
       -not -path '*/node_modules/*' 2>/dev/null | grep -q .; then
  stack="node-bun"
elif find . -maxdepth 5 -name '*.tf' \
       -not -path '*/.terraform/*' 2>/dev/null | grep -q .; then
  stack="terraform"
fi

# --- Detectar docker_directories --------------------------------------------
declare -a docker_dirs=()
while IFS= read -r dockerfile; do
  [ -z "$dockerfile" ] && continue
  dir="$(dirname "$dockerfile")"
  dir="${dir#./}"
  if [ -z "$dir" ] || [ "$dir" = "." ]; then
    docker_dirs+=("/")
  else
    docker_dirs+=("/$dir")
  fi
done < <(find . -maxdepth 6 -name 'Dockerfile' \
           -not -path '*/node_modules/*' 2>/dev/null | sort -u)

# Deduplicar preservando orden lexicográfico (bash 3.2 compatible).
if [ ${#docker_dirs[@]} -gt 0 ]; then
  dedup_csv="$(printf '%s\n' "${docker_dirs[@]}" | sort -u | tr '\n' '|')"
  unset docker_dirs
  declare -a docker_dirs=()
  IFS='|' read -ra docker_dirs <<< "${dedup_csv%|}"
fi

# --- Detectar terraform_directory (solo si stack=terraform) -----------------
# Convención observada en el manifest: el código terraform "raíz" vive en /infra
# cuando no está en la raíz del repo. Si hay *.tf directos en la raíz, no se
# emite override (default "/"). Si hay infra/*.tf, se propone /infra. Cualquier
# otro layout se deja sin override (el operador decide).
terraform_dir=""
if [ "$stack" = "terraform" ]; then
  if ls ./*.tf >/dev/null 2>&1; then
    : # tf en raíz, no override
  elif ls ./infra/*.tf >/dev/null 2>&1; then
    terraform_dir="/infra"
  else
    echo "WARN: stack=terraform pero no se detectó layout estándar (raíz ni /infra). Definir terraform_directory manualmente." >&2
  fi
fi

# --- Render YAML -------------------------------------------------------------
cat <<EOF
  - name: $REPO
    stack: $stack  # inferido
    consumes: [reusables, dependabot]
EOF

if [ -n "$terraform_dir" ] || [ ${#docker_dirs[@]} -gt 0 ]; then
  echo "    overrides:"
  if [ -n "$terraform_dir" ]; then
    echo "      terraform_directory: $terraform_dir"
  fi
  if [ ${#docker_dirs[@]} -gt 0 ]; then
    echo "      docker_directories:"
    for d in "${docker_dirs[@]}"; do
      echo "        - $d"
    done
  fi
fi
