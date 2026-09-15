#!/usr/bin/env bash
# Prompts (in a single tmux popup) for a layout and a working directory, then
# opens a new window with that layout. The layout is a whiptail radiolist
# (arrows to move, Space to mark, Enter to confirm). The working dir is a bash
# readline prompt, so it Tab-completes like a normal shell prompt.
#
# Layouts:
#   1  nvim left, claude top right, shell bottom right (shell focused)
#   2  2x2 grid: claude in three panes, shell bottom right (shell focused)
set -euo pipefail

# One entry per layout: "<key>|<label>|<function>". Adding a layout means
# adding a line here plus its function below; the radiolist is built from this
# list. The key is internal, only the label is shown.
LAYOUTS=(
  "1|nvim + claude + shell|layout_nvim_claude_shell"
  "2|3x claude + shell (2x2)|layout_claude_grid"
)
DEFAULT_LAYOUT=1

layout_nvim_claude_shell() {
  tmux new-window -n "$name" -c "$wd" "nvim"
  tmux split-window -h -l 50% -c "$wd" "claude"
  tmux split-window -v -l 50% -c "$wd"
}

layout_claude_grid() {
  # Build the grid by halves instead of by pane index: pane indices shift as
  # panes are added, but {top-left} and {bottom-right} always resolve by
  # position.
  tmux new-window -n "$name" -c "$wd" "claude"
  tmux split-window -v -l 50% -c "$wd" "claude"
  tmux split-window -h -l 50% -c "$wd"
  tmux select-pane -t '{top-left}'
  tmux split-window -h -l 50% -c "$wd" "claude"
  tmux select-pane -t '{bottom-right}'
}

# radiolist takes a flat "<tag> <item> <on|off>" triplet per row. The tag is
# what whiptail prints, so it doubles as the layout key.
rows=()
for entry in "${LAYOUTS[@]}"; do
  IFS='|' read -r key label _ <<<"$entry"
  status=off
  [ "$key" = "$DEFAULT_LAYOUT" ] && status=on
  rows+=("$key" "$label" "$status")
done

# whiptail draws on stdout and prints the result on stderr, so the two are
# swapped through fd 3: the result reaches the command substitution and the UI
# still reaches the terminal. The 0 0 0 sizes let newt fit the box to the
# content.
status=0
layout="$(whiptail --title "Layout" --notags \
  --radiolist "New window layout" 0 0 0 "${rows[@]}" \
  3>&1 1>&2 2>&3)" || status=$?

# Cancel or Esc: leave without creating a window.
if [ "$status" -ne 0 ]; then
  exit 0
fi

layout="${layout//\"/}"
layout="${layout:-$DEFAULT_LAYOUT}"

fn=""
for entry in "${LAYOUTS[@]}"; do
  IFS='|' read -r key _ candidate <<<"$entry"
  if [ "$layout" = "$key" ]; then
    fn="$candidate"
    break
  fi
done

if [ -z "$fn" ]; then
  echo "Unknown layout: $layout" >&2
  sleep 1.5
  exit 1
fi

read -e -p "Working dir: " -i "$PWD" wd
wd="${wd:-$PWD}"
wd="${wd/#\~/$HOME}"

if [ ! -d "$wd" ]; then
  echo "Not a directory: $wd" >&2
  sleep 1.5
  exit 1
fi

name="$(basename "$wd")"
"$fn"
