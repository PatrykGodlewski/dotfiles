# shellcheck shell=bash
# Machine-local state (never committed):
#   $DOT_CONFIG_DIR/selected        modules chosen on this machine, one per line
#   $DOT_STATE_DIR/installed        "module manager package" installed BY dot
#                                   (pre-existing packages are never recorded,
#                                   so prune never touches them)
#   $DOT_STATE_DIR/backups/<time>/  files moved away before linking

SEL_FILE="$DOT_CONFIG_DIR/selected"
REC_FILE="$DOT_STATE_DIR/installed"
DOT_TS=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$DOT_STATE_DIR/backups/$DOT_TS"

sel_get() { [[ -f $SEL_FILE ]] && grep -v '^\s*$' "$SEL_FILE"; return 0; }
sel_has() { sel_get | grep -qx "$1"; }

sel_write() { # sel_write name...  (replaces selection)
  [[ $DOT_DRY == 1 ]] && return 0
  mkdir -p "$DOT_CONFIG_DIR"
  printf '%s\n' "$@" | grep -v '^$' | sort -u >"$SEL_FILE"
}
sel_add() {
  local -a cur
  mapfile -t cur < <(sel_get)
  sel_write "${cur[@]}" "$@"
}
sel_del() {
  local -a keep=() n
  for n in $(sel_get); do in_list "$n" "$@" || keep+=("$n"); done
  sel_write "${keep[@]}"
}

rec_add() { # rec_add module manager pkg
  [[ $DOT_DRY == 1 ]] && return 0
  mkdir -p "$DOT_STATE_DIR"
  grep -qx "$1 $2 $3" "$REC_FILE" 2>/dev/null || echo "$1 $2 $3" >>"$REC_FILE"
}
rec_list() { [[ -f $REC_FILE ]] && cat "$REC_FILE"; return 0; }
rec_del() { # rec_del manager pkg
  [[ $DOT_DRY == 1 || ! -f $REC_FILE ]] && return 0
  local tmp="$REC_FILE.tmp"
  awk -v m="$1" -v p="$2" '!($2 == m && $3 == p)' "$REC_FILE" >"$tmp" && mv "$tmp" "$REC_FILE"
}
