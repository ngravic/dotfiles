#!/usr/bin/env bash
# Prompts for a working directory (bash readline, Tab-completes like a normal
# shell prompt) then opens a new tmux window: nvim on the left, claude on the
# top right, a plain (focused) shell on the bottom right, all sharing that
# directory.
set -euo pipefail

read -e -p "Working dir: " -i "$PWD" wd
wd="${wd/#\~/$HOME}"

if [ ! -d "$wd" ]; then
  echo "Not a directory: $wd" >&2
  sleep 1.5
  exit 1
fi

tmux new-window -n "$(basename "$wd")" -c "$wd" "nvim"
tmux split-window -h -l 50% -c "$wd" "claude"
tmux split-window -v -l 50% -c "$wd"
