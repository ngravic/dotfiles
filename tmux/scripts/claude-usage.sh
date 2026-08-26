#!/usr/bin/env bash
# Claude usage meter for the tmux status bar.
#
# Prints the short (5-hour) usage window as "58% 3h" or "98% 21m":
# percent consumed, then time left until the window resets.
#
# No network access at all. ~/.claude/statusline.pl writes the cache from the
# JSON Claude Code hands it on every status line render, so the number costs
# nothing and never hits the /api/oauth/usage rate limit. This script only
# formats what is already on disk, which is why tmux can call it once per
# second. The cache holds the raw "<percent> <reset epoch>" pair, so the
# countdown stays exact on every tick even when the reading itself is old.
set -uo pipefail

MAX_AGE="${CLAUDE_USAGE_MAX_AGE:-3600}"  # older than this, mark the reading stale

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/claude-usage"
DATA_FILE="$CACHE/data"   # "<percent>\t<reset epoch>", written by statusline.pl

# --- render: cached pair -> "58% 3h" --------------------------------------
# A trailing "*" means the reading is no longer trustworthy: either the window
# it described has already reset, or no Claude Code session has refreshed it
# for MAX_AGE seconds. The countdown itself is always computed from now.
render() {
  local pct reset now age rem stale out
  [ -s "$DATA_FILE" ] || return 1
  IFS=$'\t' read -r pct reset < "$DATA_FILE" || true
  [[ "${pct:-}" =~ ^[0-9]+$ ]] || return 1

  now="$(date +%s)"
  stale=0
  out="${pct}%"

  age=$(( now - $(stat -c %Y "$DATA_FILE" 2>/dev/null || echo "$now") ))
  [ "$age" -gt "$MAX_AGE" ] && stale=1

  if [[ "${reset:-}" =~ ^[0-9]+$ ]]; then
    rem=$(( reset - now ))
    if   [ "$rem" -le 0 ];    then stale=1
    elif [ "$rem" -ge 3600 ]; then out="$out $((rem / 3600))h"
    else                            out="$out $(( (rem + 59) / 60 ))m"
    fi
  fi

  [ "$stale" -eq 1 ] && out="$out*"
  printf '%s' "$out"
}

case "${1:-}" in
  --status)
    echo "cache:  $DATA_FILE"
    echo "data:   $(cat "$DATA_FILE" 2>/dev/null || echo '(none)')"
    echo "age:    $([ -s "$DATA_FILE" ] && echo "$(( $(date +%s) - $(stat -c %Y "$DATA_FILE") ))s" || echo '-')"
    echo "render: $(render || echo '(nothing yet)')"
    exit
    ;;
  --clear)
    rm -f "$DATA_FILE"
    exit
    ;;
esac

# Printed raw, with no #[...] style tags, so it inherits the status bar style.
# "-" means no Claude Code session has ever written the cache on this machine.
render || printf '-'
exit 0
