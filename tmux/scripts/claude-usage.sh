#!/usr/bin/env bash
# Claude usage meter for the tmux status bar.
#
# Prints the short (5-hour) usage window as "58% 3h" or "98% 21m":
# percent consumed, then time left until the window resets.
#
# tmux calls this once per second, so it never touches the network inline.
# It prints a cached string immediately and, when that cache is older than
# TTL, forks a single detached refresh in the background. A flock keeps
# concurrent refreshes down to one.
set -uo pipefail

TTL="${CLAUDE_USAGE_TTL:-60}"       # seconds between successful refreshes
ERR_TTL="${CLAUDE_USAGE_ERR_TTL:-180}"  # back off longer after a failure

CREDS="$HOME/.claude/.credentials.json"
API="https://api.anthropic.com/api/oauth/usage"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/claude-usage"
DISPLAY_FILE="$CACHE/display"
NEXT_FILE="$CACHE/next"
LOCK_FILE="$CACHE/lock"

mkdir -p "$CACHE"

# --- fetch: prints the raw API response on stdout -------------------------
fetch_raw() {
  local token
  token="$(jq -r '.claudeAiOauth.accessToken // .accessToken // empty' "$CREDS" 2>/dev/null)"
  [ -n "$token" ] || return 1
  curl -sS --max-time 10 \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "Content-Type: application/json" \
    "$API"
}

# --- parse: raw JSON on stdin -> "<percent>\t<reset>" ---------------------
# Primary source is .five_hour; the .limits array (kind == "session") is the
# fallback in case the top-level key ever goes away.
parse() {
  jq -r '
    ( if (.five_hour? | type) == "object" and (.five_hour.utilization != null)
      then { u: .five_hour.utilization, r: .five_hour.resets_at }
      else ( (.limits? // []) | map(select(.kind == "session")) | first
             | if . then { u: .percent, r: .resets_at } else null end )
      end ) as $w
    | if ($w == null) or ($w.u == null) then empty
      else "\($w.u)\t\($w.r // "")" end
  ' 2>/dev/null
}

# --- format: "<percent>\t<reset>" -> "58% 3h" ------------------------------
format() {
  local pct reset now rem out
  # `read` returns 1 at EOF on unterminated input but still assigns, so gate
  # on the value instead of the exit status.
  IFS=$'\t' read -r pct reset || true
  [ -n "${pct:-}" ] || return 1

  # Percent may arrive as a 0-1 fraction or as 0-100.
  pct="$(awk -v p="$pct" 'BEGIN{ if (p=="" || p+0!=p) exit 1; if (p<=1) p=p*100; printf "%d", (p+0.5) }')" || return 1

  out="${pct}%"

  if [ -n "${reset:-}" ] && [ "$reset" != "null" ]; then
    now="$(date +%s)"
    if [[ "$reset" =~ ^[0-9]+$ ]]; then
      # Epoch, in seconds or milliseconds.
      [ "${#reset}" -ge 12 ] && reset=$((reset / 1000))
    else
      reset="$(date -d "$reset" +%s 2>/dev/null)" || reset=""
    fi
    if [ -n "$reset" ]; then
      rem=$(( reset - now ))
      if   [ "$rem" -le 0 ];    then out="$out 0m"
      elif [ "$rem" -ge 3600 ]; then out="$out $((rem / 3600))h"
      else                            out="$out $(( (rem + 59) / 60 ))m"
      fi
    fi
  fi

  printf '%s' "$out"
}

refresh() {
  # Claim the window up front so a slow request does not let others pile in.
  echo "$(( $(date +%s) + TTL ))" > "$NEXT_FILE"

  local raw parsed text
  raw="$(fetch_raw)" || { echo "$(( $(date +%s) + ERR_TTL ))" > "$NEXT_FILE"; return 1; }
  parsed="$(printf '%s' "$raw" | parse)"
  [ -n "$parsed" ] || { echo "$(( $(date +%s) + ERR_TTL ))" > "$NEXT_FILE"; return 1; }
  text="$(printf '%s' "$parsed" | format)" || { echo "$(( $(date +%s) + ERR_TTL ))" > "$NEXT_FILE"; return 1; }

  printf '%s' "$text" > "$DISPLAY_FILE.tmp" && mv "$DISPLAY_FILE.tmp" "$DISPLAY_FILE"
  echo "$(( $(date +%s) + TTL ))" > "$NEXT_FILE"
}

case "${1:-}" in
  --raw)
    fetch_raw
    exit
    ;;
  --refresh)
    # Synchronous refresh, for testing.
    refresh && cat "$DISPLAY_FILE" && echo
    exit
    ;;
  --clear)
    rm -f "$DISPLAY_FILE" "$NEXT_FILE" "$LOCK_FILE"
    exit
    ;;
esac

now="$(date +%s)"
next="$(cat "$NEXT_FILE" 2>/dev/null || echo 0)"
[[ "$next" =~ ^[0-9]+$ ]] || next=0

if [ "$now" -ge "$next" ]; then
  # Detached so tmux never waits on the network.
  setsid bash -c '
    exec 9>"$1"
    flock -n 9 || exit 0
    "$0" --refresh >/dev/null 2>&1
  ' "$0" "$LOCK_FILE" >/dev/null 2>&1 < /dev/null &
  disown 2>/dev/null || true
fi

# Printed raw, with no #[...] style tags, so it inherits the status bar style.
if [ -s "$DISPLAY_FILE" ]; then
  cat "$DISPLAY_FILE"
fi
