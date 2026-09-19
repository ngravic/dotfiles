#!/usr/bin/env bash
# Helpers para los install.sh de cada carpeta. Sourcealo, no lo ejecutes.
#
#   link <origen-en-el-repo> <destino>   symlink idempotente
#   ensure_dir <ruta>                    mkdir -p
#   summary                              totales; devuelve 1 si hubo conflictos
#
# Variables que respeta:
#   DOTFILES   raiz del repo. Si no esta, la deduce de la ubicacion del script.
#   DRY_RUN=1  no toca nada, solo imprime.
#   ADOPT=1    mueve a <destino>.pre-dotfiles lo que estorba y hace el symlink.

[ -n "${DOTFILES_LIB:-}" ] && return 0
DOTFILES_LIB=1

: "${DOTFILES:=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
: "${DRY_RUN:=0}"
: "${ADOPT:=0}"

_n_creados=0
_n_ok=0
_n_conflictos=0

if [ -t 1 ]; then
  _c_creado=$'\e[32m'; _c_ok=$'\e[90m'; _c_conflicto=$'\e[33m'; _c_off=$'\e[0m'
else
  _c_creado=''; _c_ok=''; _c_conflicto=''; _c_off=''
fi

_tilde() { printf '%s' "${1/#$HOME/\~}"; }

_log() {
  local estado="$1" texto="$2" color
  case "$estado" in
    creado)     color="$_c_creado" ;;
    ok)         color="$_c_ok" ;;
    *)          color="$_c_conflicto" ;;
  esac
  printf '  %s%-10s%s %s\n' "$color" "$estado" "$_c_off" "$texto"
}

_conflicto() {
  _log conflicto "$1"
  _n_conflictos=$((_n_conflictos + 1))
}

ensure_dir() {
  local d="$1"
  if [ -d "$d" ]; then
    return 0
  fi
  if [ -e "$d" ] || [ -L "$d" ]; then
    _conflicto "$(_tilde "$d") existe y no es carpeta"
    return 0
  fi
  [ "$DRY_RUN" = 1 ] || mkdir -p "$d"
  _log creado "$(_tilde "$d")/"
  _n_creados=$((_n_creados + 1))
}

link() {
  local src="$1" dst="$2"
  [ "${src#/}" = "$src" ] && src="$DOTFILES/$src"

  if [ ! -e "$src" ]; then
    _conflicto "$(_tilde "$dst"): falta el origen $(_tilde "$src")"
    return 0
  fi

  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    _log ok "$(_tilde "$dst")"
    _n_ok=$((_n_ok + 1))
    return 0
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ "$ADOPT" != 1 ]; then
      _conflicto "$(_tilde "$dst") ya existe y no apunta al repo; mirá --adopt"
      return 0
    fi
    [ "$DRY_RUN" = 1 ] || mv "$dst" "$dst.pre-dotfiles"
    _log creado "$(_tilde "$dst").pre-dotfiles (lo que estaba)"
    _n_creados=$((_n_creados + 1))
  fi

  ensure_dir "$(dirname "$dst")"
  [ "$DRY_RUN" = 1 ] || ln -s "$src" "$dst"
  _log creado "$(_tilde "$dst") -> $(_tilde "$src")"
  _n_creados=$((_n_creados + 1))
}

summary() {
  printf '\ncreados %s   ok %s   conflictos %s\n' "$_n_creados" "$_n_ok" "$_n_conflictos"
  [ "$_n_conflictos" -eq 0 ]
}

# Subscript corrido a mano: el resumen lo imprime el trap. Con el orquestador
# lo imprime el, una sola vez al final.
if [ -z "${DOTFILES_ORCHESTRATED:-}" ]; then
  trap '_rc=$?; summary || _rc=1; exit $_rc' EXIT
fi
