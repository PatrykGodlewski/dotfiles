# shellcheck shell=bash
# The Omarchy profile (modules/omarchy/profile): plain `omarchy` commands, one
# per line, "#" comments, optional leading "omarchy".
#
# Nothing in the profile is ever evaluated: words are split with shell-style
# quoting (by xargs), but $(...), variables and globs stay literal text.

PROFILE_FILE="$DOT_ROOT/modules/omarchy/profile"

# profile_strip <raw line> -> the command (no comment, no "omarchy"), or ""
profile_strip() {
  local l=$1
  [[ $l =~ ^[[:space:]]*# ]] && return 0
  l=${l%%[[:space:]]#*}
  l="${l#"${l%%[![:space:]]*}"}"
  l="${l%"${l##*[![:space:]]}"}"
  [[ $l =~ ^omarchy[[:space:]]+(.*)$ ]] && l=${BASH_REMATCH[1]}
  printf '%s' "$l"
}

# profile_entries [file] -> "lineno<TAB>command" for every active line
profile_entries() {
  local f=${1:-$PROFILE_FILE} n=0 line cmd
  [[ -f $f ]] || return 0
  while IFS= read -r line || [[ -n $line ]]; do
    n=$((n + 1))
    cmd=$(profile_strip "$line")
    [[ -n $cmd ]] && printf '%s\t%s\n' "$n" "$cmd"
  done <"$f"
}

# profile_split <command> -> its words, one per line
profile_split() {
  [[ -n ${1//[[:space:]]/} ]] || return 0
  xargs printf '%s\n' <<<"$1"
}

# profile_join <word>... -> one command line, quoting words that need it
profile_join() {
  local out='' w
  for w in "$@"; do
    [[ -z $w || $w =~ [[:space:]\'\"] ]] && w="\"$w\""
    out+=${out:+ }$w
  done
  printf '%s\n' "$out"
}

# profile_key <command> -> identity; a command replaces the one with the same key
#   default <kind> <x>  -> "default <kind>"     theme/font set <x> -> "theme set"/"font set"
#   anything else       -> the normalized command itself
profile_key() {
  local -a w
  mapfile -t w < <(profile_split "$1")
  case ${w[0]:-}:${w[1]:-} in
    default:*) printf 'default %s\n' "${w[1]}" ;;
    theme:set | font:set) printf '%s set\n' "${w[0]}" ;;
    *) profile_join "${w[@]}" ;;
  esac
}

# profile_find <key> [file] -> "lineno<TAB>command" of the active line with that key
profile_find() {
  local key=$1 n cmd
  while IFS=$'\t' read -r n cmd; do
    [[ $(profile_key "$cmd") == "$key" ]] && { printf '%s\t%s\n' "$n" "$cmd"; return 0; }
  done < <(profile_entries "${2:-$PROFILE_FILE}")
  return 1
}

# profile_with_set <file> <command>...  -> file content with each command set:
# replaces the active line with the same key, otherwise appends it
profile_with_set() {
  local f=$1 i cmd k; shift
  local -a lines=() append=()
  local -A at=()
  [[ -f $f ]] && mapfile -t lines <"$f"
  for i in "${!lines[@]}"; do
    cmd=$(profile_strip "${lines[i]}")
    [[ -n $cmd ]] && at[$(profile_key "$cmd")]=$i
  done
  for cmd in "$@"; do
    k=$(profile_key "$cmd")
    if [[ -n ${at[$k]:-} ]]; then
      [[ ${at[$k]} == new ]] || lines[at[$k]]=$cmd
    else
      append+=("$cmd")
      at[$k]=new
    fi
  done
  ((${#lines[@]})) && printf '%s\n' "${lines[@]}"
  ((${#append[@]})) && printf '%s\n' "${append[@]}"
  return 0
}

# profile_without <file> <lineno>...  -> file content without those lines
profile_without() {
  local f=$1; shift
  awk -v drop=" $* " 'index(drop, " " NR " ") == 0' "$f"
}

# profile_write <file> <new content file> [diff already shown: 1]
# Shows the diff, confirms, writes. Returns 1 if nothing changed or declined.
profile_write() {
  local f=$1 new=$2 shown=${3:-0}
  if [[ -f $f ]] && cmp -s "$f" "$new"; then
    info "profile unchanged"
    return 1
  fi
  ((shown)) || show_diff "$f" "$new" "$(pretty "$f")"
  [[ $DOT_DRY == 1 ]] && return 0
  ui_confirm "Save $(pretty "$f")?" || { info "Not saved."; return 1; }
  mkdir -p "$(dirname "$f")"
  cat "$new" >"$f"
  ok "saved $(pretty "$f")"
}
