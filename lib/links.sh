# shellcheck shell=bash
# Config linking. Everything under modules/<m>/home/ mirrors $HOME.
# Linking granularity: the first path component that is NOT a "container".
#   home/.zshrc                  -> ~/.zshrc
#   home/.config/nvim/           -> ~/.config/nvim         (whole directory)
#   home/.local/bin/foo          -> ~/.local/bin/foo
#   home/.local/scripts/         -> ~/.local/scripts       (whole directory)
LINK_CONTAINERS=(.config .local .local/share .local/bin)

# links_of <module>  -> lines "src<TAB>dst"
links_of() {
  local home="$DOT_ROOT/modules/$1/home"
  [[ -d $home ]] || return 0
  _links_walk "$home" ""
}

_links_walk() {
  local home=$1 rel=$2 e r
  local -a entries
  local restore; restore=$(shopt -p nullglob dotglob)
  shopt -s nullglob dotglob
  entries=("$home/${rel:+$rel/}"*)
  eval "$restore"
  for e in "${entries[@]}"; do
    r=${rel:+$rel/}${e##*/}
    [[ ${e##*/} == .gitkeep ]] && continue
    if [[ -d $e && ! -L $e ]] && in_list "$r" "${LINK_CONTAINERS[@]}"; then
      _links_walk "$home" "$r"
    else
      printf '%s\t%s\n' "$e" "$HOME/$r"
    fi
  done
}

# link_unit <path relative to $HOME> -> the part that would be linked
link_unit() {
  local rel=$1 acc='' part
  local IFS=/
  for part in $rel; do
    acc=${acc:+$acc/}$part
    in_list "$acc" "${LINK_CONTAINERS[@]}" || { printf '%s\n' "$acc"; return; }
  done
  printf '%s\n' "$acc"
}

# link_state <src> <dst> -> ok | missing | conflict | same | foreign
#   same    = a real file/dir with identical content (an old copy)
#   foreign = a symlink pointing somewhere else
link_state() {
  local src=$1 dst=$2
  if [[ -L $dst ]]; then
    [[ $(readlink "$dst") == "$src" ]] && echo ok || echo foreign
  elif [[ -e $dst ]]; then
    if diff -rq "$src" "$dst" >/dev/null 2>&1; then echo same; else echo conflict; fi
  else
    echo missing
  fi
}

_backup() {
  local dst=$1 rel=${1#"$HOME"/}
  run mkdir -p "$(dirname "$BACKUP_DIR/$rel")" && run mv "$dst" "$BACKUP_DIR/$rel"
}

link_apply() {
  local src=$1 dst=$2 st
  st=$(link_state "$src" "$dst")
  case $st in
    ok) return 0 ;;
    conflict | same | foreign) _backup "$dst" || return 1 ;;
  esac
  run mkdir -p "$(dirname "$dst")" && run ln -s "$src" "$dst"
}

link_remove() {
  local src=$1 dst=$2
  if [[ -L $dst && $(readlink "$dst") == "$src" ]]; then run rm "$dst"; fi
}
