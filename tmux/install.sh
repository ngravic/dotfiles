#!/usr/bin/env bash
# Config de tmux. Los scripts de tmux/scripts/ los llama tmux.conf por ruta
# absoluta al repo, asi que no se symlinkean.
set -euo pipefail
: "${DOTFILES:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib.sh
source "$DOTFILES/lib.sh"

link tmux/tmux.conf "$HOME/.tmux.conf"
