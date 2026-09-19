#!/usr/bin/env bash
# Config de Claude Code. ~/.claude mezcla config con estado en tiempo de
# ejecucion, asi que se symlinkea archivo por archivo, no la carpeta entera.
set -euo pipefail
: "${DOTFILES:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib.sh
source "$DOTFILES/lib.sh"

ensure_dir "$HOME/.claude"
for f in CLAUDE.md settings.json statusline.pl commands skills memory; do
  link "claude/$f" "$HOME/.claude/$f"
done

# hooks/ no va entera: Claude Code guarda ahi sus propios README.md y hooks.json.
ensure_dir "$HOME/.claude/hooks"
link claude/hooks/tasks-brief.py "$HOME/.claude/hooks/tasks-brief.py"
