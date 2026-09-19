#!/usr/bin/env bash
# Config de nvim. Archivo por archivo: ~/.config/nvim tambien guarda estado que
# no va al repo.
set -euo pipefail
: "${DOTFILES:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib.sh
source "$DOTFILES/lib.sh"

ensure_dir "$HOME/.config/nvim"
link nvim/init.lua       "$HOME/.config/nvim/init.lua"
link nvim/lazy-lock.json "$HOME/.config/nvim/lazy-lock.json"
