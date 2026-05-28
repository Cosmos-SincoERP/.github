#!/usr/bin/env bash
# scan-repo.sh — escanea un repo de la org y propone su bloque de manifest.
#
# Uso: bash .github/scripts/scan-repo.sh <repo-name>
#
# Hace un clone shallow temporal del repo en Cosmos-SincoERP, infiere el stack
# y detecta overrides (docker_directories, terraform_directory). Imprime el
# bloque YAML listo para pegar en docs/repos-manifest.yml.
#
# La lógica de detección vive en lib-scan.sh (compartida con drift-check).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-scan.sh
source "$SCRIPT_DIR/lib-scan.sh"
# shellcheck source=lib-render.sh
source "$SCRIPT_DIR/lib-render.sh"

ORG="${ORG:-Cosmos-SincoERP}"
REPO="${1:-}"

if [ -z "$REPO" ]; then
  echo "Uso: bash .github/scripts/scan-repo.sh <repo-name>" >&2
  exit 1
fi

WORKDIR="$(mktemp -d -t scan-repo-XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

CLONE_DIR="$WORKDIR/$REPO"

if ! gh repo clone "$ORG/$REPO" "$CLONE_DIR" -- --quiet --depth 1 2>"$WORKDIR/clone.err"; then
  echo "ERROR: no se pudo clonar $ORG/$REPO" >&2
  sed 's/^/  /' "$WORKDIR/clone.err" >&2
  exit 2
fi

# Repo vacío: clone --depth 1 deja solo .git/. Avisar y emitir baseline.
if [ -z "$(ls -A "$CLONE_DIR" 2>/dev/null | grep -v '^\.git$' || true)" ]; then
  echo "WARN: $ORG/$REPO está vacío (sin commits). Emitiendo baseline; revisar cuando tenga contenido." >&2
fi

stack="$(scan_detect_stack "$CLONE_DIR")"

# docker_directories como CSV (formato que consume emit_manifest_entry).
docker_dirs_csv="$(scan_detect_docker_dirs "$CLONE_DIR" | tr '\n' ',' | sed 's/,$//')"

terraform_dir=""
if [ "$stack" = "terraform" ]; then
  terraform_dir="$(scan_detect_terraform_dir "$CLONE_DIR")"
  if [ "$terraform_dir" = "UNKNOWN" ]; then
    echo "WARN: stack=terraform pero no se detectó layout estándar (raíz ni /infra). Definir terraform_directory manualmente." >&2
    terraform_dir=""
  fi
fi

# emit_manifest_entry vive en lib-render.sh (compartida con create-repo.sh).
emit_manifest_entry "$REPO" "$stack" "reusables,dependabot" "$terraform_dir" "$docker_dirs_csv" "# inferido"
