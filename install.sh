#!/usr/bin/env bash
# Instala los dotfiles en esta maquina: crea carpetas y symlinks.
#
# Es idempotente: lo que ya esta bien lo deja como esta. Correlo cada vez que
# pulleas cambios.
#
# Corre un install.sh por carpeta. Para sumar una config nueva, poné su
# install.sh dentro de la carpeta. Este archivo no se toca.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
ADOPT=0

usage() {
  cat <<'USO'
uso: ./install.sh [-n|--dry-run] [--adopt]

  -n, --dry-run   muestra que haria, no toca nada
      --adopt     si el destino ya existe y no apunta al repo, lo mueve a
                  <destino>.pre-dotfiles y hace el symlink
USO
}

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1 ;;
    --adopt)      ADOPT=1 ;;
    -h|--help)    usage; exit 0 ;;
    *)            echo "opcion desconocida: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

export DOTFILES DRY_RUN ADOPT
DOTFILES_ORCHESTRATED=1
# shellcheck source=lib.sh
source "$DOTFILES/lib.sh"

[ "$DRY_RUN" = 1 ] && echo "dry-run: no se toca nada"

for sub in "$DOTFILES"/*/install.sh; do
  [ -e "$sub" ] || continue
  printf '\n%s\n' "$(basename "$(dirname "$sub")")"
  # shellcheck source=/dev/null
  source "$sub"
done

summary
