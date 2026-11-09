# shellcheck shell=bash
# Interactive prompts. Uses gum when available, plain bash prompts otherwise.
# Menu items are passed as "name<TAB>description"; functions print chosen names.

ui_interactive() { [[ -t 0 && -t 2 ]]; }
ui_gum() { has gum && ui_interactive && [[ -z ${DOT_NO_GUM:-} ]]; }

# ui_confirm "Question?"  -> 0 yes / 1 no
ui_confirm() {
  [[ $DOT_YES == 1 ]] && return 0
  if ! ui_interactive; then
    warn "$1 — not a terminal, pass --yes to confirm"
    return 1
  fi
  if ui_gum; then
    gum confirm "$1"
    return
  fi
  local a
  read -rp "$1 [y/N] " a
  [[ $a =~ ^[Yy] ]]
}

# ui_input "Prompt" [default]
ui_input() {
  local prompt=$1 def=${2:-} a
  if ui_gum; then
    gum input --header "$prompt" --value "$def" --width 72
    return
  fi
  read -rp "$prompt${def:+ [$def]}: " a
  printf '%s\n' "${a:-$def}"
}

# Render "name<TAB>desc" as an aligned display line (no commas: gum uses them
# as separators for --selected).
_ui_line() {
  local name=${1%%$'\t'*} desc=''
  [[ $1 == *$'\t'* ]] && desc=${1#*$'\t'}
  desc=${desc//,/;}
  printf "%-${UI_NAME_W:-14}s %s" "$name" "$desc"
}

# ui_choose_one "Header" item...
ui_choose_one() {
  local h=$1; shift
  local -a lines=() names=()
  local it
  for it in "$@"; do lines+=("$(_ui_line "$it")"); names+=("${it%%$'\t'*}"); done
  if ui_gum; then
    local out
    out=$(gum choose --header "$h" --height 15 "${lines[@]}") || return 1
    awk '{print $1}' <<<"$out"
    return
  fi
  printf '%s%s%s\n' "$C_BOLD" "$h" "$C_RESET" >&2
  local i
  for i in "${!lines[@]}"; do printf '  %2d) %s\n' $((i + 1)) "${lines[i]}" >&2; done
  local a
  read -rp "Choose [1-${#lines[@]}]: " a
  [[ $a =~ ^[0-9]+$ && $a -ge 1 && $a -le ${#lines[@]} ]] || return 1
  printf '%s\n' "${names[a - 1]}"
}

# ui_choose_many "Header" "preselected names (space separated)" item...
ui_choose_many() {
  local h=$1 pre=" $2 "; shift 2
  local -a lines=() names=() sel=()
  local it n
  for it in "$@"; do
    n=${it%%$'\t'*}
    names+=("$n")
    lines+=("$(_ui_line "$it")")
    [[ $pre == *" $n "* ]] && sel+=("${lines[-1]}")
  done
  if ui_gum; then
    local selected out
    selected=$(IFS=,; echo "${sel[*]}")
    out=$(gum choose --no-limit --height 20 --header "$h" \
      --selected "$selected" "${lines[@]}") || return 1
    awk 'NF {print $1}' <<<"$out"
    return
  fi
  # Plain fallback: toggle by number
  local -A on=()
  for n in "${names[@]}"; do [[ $pre == *" $n "* ]] && on[$n]=1; done
  local a i
  while true; do
    printf '\n%s%s%s\n' "$C_BOLD" "$h" "$C_RESET" >&2
    for i in "${!names[@]}"; do
      if [[ -n ${on[${names[i]}]:-} ]]; then n="${C_GREEN}[x]${C_RESET}"; else n='[ ]'; fi
      printf '  %2d) %s %s\n' $((i + 1)) "$n" "${lines[i]}" >&2
    done
    read -rp "Toggle numbers (e.g. '1 4 7'), 'a' all, 'n' none, Enter to accept: " a
    [[ -z $a ]] && break
    case $a in
      a) for n in "${names[@]}"; do on[$n]=1; done; continue ;;
      n) on=(); continue ;;
    esac
    for i in $a; do
      [[ $i =~ ^[0-9]+$ && $i -ge 1 && $i -le ${#names[@]} ]] || continue
      n=${names[i - 1]}
      if [[ -n ${on[$n]:-} ]]; then unset "on[$n]"; else on[$n]=1; fi
    done
  done
  for n in "${names[@]}"; do [[ -n ${on[$n]:-} ]] && printf '%s\n' "$n"; done
  return 0
}
