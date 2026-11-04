# shellcheck shell=bash
# Modules: modules/<name>/module.sh (+ optional home/ tree that gets linked).
#
# Variables a module may set (all optional):
#   DESC="..."            one line description
#   DEPENDS=(mod ...)     installed first
#   ONLY_ON=(arch|debian|ubuntu|wsl|...)   skip unless one tag matches
#   SKIP_ON=(wsl ...)                      skip if any tag matches
#   REQUIRED=1            always installed (core)
#   PKGS=(...)            same name on every distro -> native manager
#   PACMAN=() AUR=() APT=() CARGO=() FLATPAK=() SERVICES=()   per manager
# Hook functions (all optional):
#   is_installed   return 0 when the custom part (setup) is already done
#   setup          custom install steps; runs when is_installed fails
#   configure      runs on every apply after linking; must be idempotent
#   teardown       runs on `dot remove`

MOD_HOOKS=(is_installed setup configure teardown)

mod_all() {
  local d
  for d in "$DOT_ROOT"/modules/*/; do
    [[ -f $d/module.sh ]] && basename "$d"
  done
}

mod_exists() { [[ -f $DOT_ROOT/modules/$1/module.sh ]]; }

# Load a module into the current shell (resets previous module's vars/hooks).
mod_load() {
  local name=$1 v
  unset DESC DEPENDS ONLY_ON SKIP_ON REQUIRED PKGS
  for v in "${MGR_VAR[@]}"; do unset "$v"; done
  unset -f "${MOD_HOOKS[@]}" 2>/dev/null
  DESC='' DEPENDS=() ONLY_ON=() SKIP_ON=() REQUIRED=0 PKGS=()
  MOD_NAME=$name
  MOD_DIR="$DOT_ROOT/modules/$name"
  # shellcheck disable=SC1091
  source "$MOD_DIR/module.sh"
}

mod_has_hook() { [[ $(type -t "$1") == function ]]; }

# Why is the loaded module unsupported here? Prints reason, returns 1 if unsupported.
mod_supported() {
  local t
  if ((${#ONLY_ON[@]})); then
    local hit=0
    for t in "${ONLY_ON[@]}"; do in_list "$t" "${OS_TAGS[@]}" && hit=1; done
    ((hit)) || { echo "only on ${ONLY_ON[*]}"; return 1; }
  fi
  for t in "${SKIP_ON[@]}"; do
    in_list "$t" "${OS_TAGS[@]}" && { echo "skipped on $t"; return 1; }
  done
  return 0
}

# Packages of the loaded module for manager $1 (PKGS goes to the native one).
mod_pkgs() {
  local m=$1 var=${MGR_VAR[$1]}
  local -n _arr=$var 2>/dev/null
  local -a out=()
  [[ $m == "$(native_manager)" ]] && out+=("${PKGS[@]}")
  [[ $(declare -p "$var" 2>/dev/null) == "declare -a"* ]] && out+=("${_arr[@]}")
  ((${#out[@]})) && printf '%s\n' "${out[@]}"
  return 0
}

mod_desc() { mod_load "$1"; printf '%s' "$DESC"; }

# Resolve names (and @preset refs) to an ordered, de-duplicated list with
# dependencies first and REQUIRED modules at the front.
declare -ga RESOLVED=()
resolve() {
  RESOLVED=()
  local -A seen=()
  local n
  for n in $(mod_all); do
    mod_load "$n"
    [[ $REQUIRED == 1 ]] && _resolve_one "$n"
  done
  for n in "$@"; do
    if [[ $n == @* ]]; then
      local p
      for p in $(preset_modules "${n#@}"); do _resolve_one "$p"; done
    else
      _resolve_one "$n"
    fi
  done
}
_resolve_one() {
  local n=$1 d
  [[ -n ${seen[$n]:-} ]] && return 0
  seen[$n]=1
  mod_exists "$n" || { warn "unknown module: $n"; return 0; }
  mod_load "$n"
  local -a deps=("${DEPENDS[@]}")
  for d in "${deps[@]}"; do _resolve_one "$d"; done
  RESOLVED+=("$n")
}

# ---------- presets ----------
preset_all() {
  local f
  for f in "$DOT_ROOT"/presets/*; do [[ -f $f ]] && basename "$f"; done
}
preset_desc() { sed -n '1s/^#\s*//p' "$DOT_ROOT/presets/$1"; }
preset_modules() { # expands @includes
  local f="$DOT_ROOT/presets/$1" line
  [[ -f $f ]] || { warn "unknown preset: $1"; return 0; }
  while read -r line; do
    line=${line%%#*}
    line=${line//[[:space:]]/}
    [[ -z $line ]] && continue
    if [[ $line == @* ]]; then preset_modules "${line#@}"; else echo "$line"; fi
  done <"$f" | awk '!seen[$0]++'
}

# ---------- plan ----------
_sym() { # _sym + | = | ! | - | ~
  case $1 in
    +) printf '%s+%s' "$C_GREEN" "$C_RESET" ;;
    =) printf '%s=%s' "$C_DIM" "$C_RESET" ;;
    '!') printf '%s!%s' "$C_YELLOW" "$C_RESET" ;;
    -) printf '%s-%s' "$C_RED" "$C_RESET" ;;
    '~') printf '%s~%s' "$C_DIM" "$C_RESET" ;;
  esac
}

# mod_plan <name>  — print what apply would do. Sets PLAN_CHANGES (count).
PLAN_CHANGES=0
mod_plan() {
  local name=$1 m p st src dst why changes=0 line
  mod_load "$name"
  printf '\n%s▸ %s%s  %s%s%s\n' "$C_BOLD" "$name" "$C_RESET" "$C_DIM" "$DESC" "$C_RESET"
  if ! why=$(mod_supported); then
    printf '    %s %s\n' "$(_sym '~')" "skip — $why"
    PLAN_CHANGES=0
    return 0
  fi
  for m in "${MGR_ORDER[@]}"; do
    mgr_relevant "$m" || continue
    local -a pk=()
    mapfile -t pk < <(mod_pkgs "$m")
    ((${#pk[@]})) || continue
    line=''
    if ! mgr "$m" m_available; then
      printf '    %-9s %s %s %s(%s not available here)%s\n' "$m" "$(_sym '~')" "${pk[*]}" "$C_DIM" "$m" "$C_RESET"
      continue
    fi
    for p in "${pk[@]}"; do
      if mgr "$m" m_has "$p"; then
        line+=" $(_sym '=') $C_DIM$p$C_RESET"
      else
        line+=" $(_sym +) $p"
        ((changes++))
      fi
    done
    printf '    %-9s%s\n' "$m" "$line"
  done
  if mod_has_hook setup; then
    if mod_has_hook is_installed && (is_installed) >/dev/null 2>&1; then
      printf '    %-9s %s %salready done%s\n' setup "$(_sym '=')" "$C_DIM" "$C_RESET"
    elif ((changes)) && mod_has_hook is_installed; then
      printf '    %-9s %s run setup() %sonly if still missing after the packages above%s\n' setup "$(_sym +)" "$C_DIM" "$C_RESET"
      if [[ $DOT_VERBOSE == 1 ]]; then
        declare -f setup | sed '1,2d;$d' | sed "s/^/              $C_DIM/;s/\$/$C_RESET/"
      fi
    else
      printf '    %-9s %s run setup()\n' setup "$(_sym +)"
      ((changes++))
      if [[ $DOT_VERBOSE == 1 ]]; then
        declare -f setup | sed '1,2d;$d' | sed "s/^/              $C_DIM/;s/\$/$C_RESET/"
      fi
    fi
  fi
  while IFS=$'\t' read -r src dst; do
    [[ -z $src ]] && continue
    st=$(link_state "$src" "$dst")
    case $st in
      ok) printf '    %-9s %s %s%s%s\n' link "$(_sym '=')" "$C_DIM" "$(pretty "$dst")" "$C_RESET" ;;
      missing) printf '    %-9s %s %s\n' link "$(_sym +)" "$(pretty "$dst")"; ((changes++)) ;;
      same) printf '    %-9s %s %s %s(identical copy → replace with link)%s\n' link "$(_sym +)" "$(pretty "$dst")" "$C_DIM" "$C_RESET"; ((changes++)) ;;
      conflict) printf '    %-9s %s %s %s(exists, differs → backed up)%s\n' link "$(_sym '!')" "$(pretty "$dst")" "$C_YELLOW" "$C_RESET"; ((changes++)) ;;
      foreign) printf '    %-9s %s %s %s(symlink to %s → backed up)%s\n' link "$(_sym '!')" "$(pretty "$dst")" "$C_YELLOW" "$(pretty "$(readlink "$dst")")" "$C_RESET"; ((changes++)) ;;
    esac
  done < <(links_of "$name")
  if mod_has_hook configure; then
    printf '    %-9s %s run configure() %s(idempotent, every apply)%s\n' configure "$(_sym '~')" "$C_DIM" "$C_RESET"
  fi
  PLAN_CHANGES=$changes
}

# ---------- apply ----------
# Runs in a subshell so a failing module can't take down the whole run.
mod_apply() {
  (
    local name=$1 m p src dst rc why
    mod_load "$name"
    if ! why=$(mod_supported); then
      info "$name: skipped ($why)"
      exit 3
    fi
    header "$name"
    for m in "${MGR_ORDER[@]}"; do
      mgr_relevant "$m" || continue
      local -a pk=() missing=()
      mapfile -t pk < <(mod_pkgs "$m")
      ((${#pk[@]})) || continue
      if ! mgr "$m" m_available; then
        warn "$m not available here, skipping: ${pk[*]}"
        continue
      fi
      for p in "${pk[@]}"; do mgr "$m" m_has "$p" || missing+=("$p"); done
      ((${#missing[@]})) || { ok "$m: all present (${pk[*]})"; continue; }
      info "$m: installing ${missing[*]}"
      mgr "$m" m_ensure || { err "$m: bootstrap failed"; exit 1; }
      mgr "$m" m_install "${missing[@]}" || { err "$m: install failed"; exit 1; }
      for p in "${missing[@]}"; do rec_add "$name" "$m" "$p"; done
    done
    if mod_has_hook setup; then
      if mod_has_hook is_installed && (is_installed) >/dev/null 2>&1; then
        ok "setup: already done"
      elif [[ $DOT_DRY == 1 ]]; then
        printf '  %s[dry]%s setup()  (see: dot plan -v %s)\n' "$C_DIM" "$C_RESET" "$name"
      else
        info "running setup()"
        (set -e; setup); rc=$?
        ((rc == 0)) || { err "setup() failed (exit $rc)"; exit 1; }
      fi
    fi
    while IFS=$'\t' read -r src dst; do
      [[ -z $src ]] && continue
      if [[ $(link_state "$src" "$dst") == ok ]]; then continue; fi
      link_apply "$src" "$dst" || { err "link failed: $(pretty "$dst")"; exit 1; }
      ok "linked $(pretty "$dst")"
    done < <(links_of "$name")
    if mod_has_hook configure; then
      if [[ $DOT_DRY == 1 ]]; then
        printf '  %s[dry]%s configure()\n' "$C_DIM" "$C_RESET"
      else
        (set -e; configure); rc=$?
        ((rc == 0)) || { err "configure() failed (exit $rc)"; exit 1; }
      fi
    fi
    exit 0
  )
}

# Remove: unlink configs + teardown hook (packages handled by prune).
mod_unlink() {
  (
    local name=$1 src dst
    mod_load "$name"
    while IFS=$'\t' read -r src dst; do
      [[ -z $src ]] && continue
      if [[ $(link_state "$src" "$dst") == ok ]]; then
        link_remove "$src" "$dst" && ok "unlinked $(pretty "$dst")"
      fi
    done < <(links_of "$name")
  )
}

mod_teardown() {
  (
    mod_load "$1"
    if mod_has_hook teardown; then
      if [[ $DOT_DRY == 1 ]]; then
        printf '  %s[dry]%s teardown()\n' "$C_DIM" "$C_RESET"
      else
        (set -e; teardown) || err "teardown() failed"
      fi
    fi
  )
}

# Status of one module: prints "pk_ok pk_total setup links_ok links_total conflicts supported_reason"
mod_status() {
  local name=$1 m p src dst st
  local pk_ok=0 pk_total=0 setup='-' l_ok=0 l_total=0 l_bad=0 why=''
  mod_load "$name"
  if ! why=$(mod_supported); then
    printf '%s\n' "unsupported|$why"
    return
  fi
  for m in "${MGR_ORDER[@]}"; do
    mgr_relevant "$m" || continue
    mgr "$m" m_available || continue
    while read -r p; do
      [[ -z $p ]] && continue
      ((pk_total++))
      mgr "$m" m_has "$p" && ((pk_ok++))
    done < <(mod_pkgs "$m")
  done
  if mod_has_hook is_installed; then
    if (is_installed) >/dev/null 2>&1; then setup=yes; else setup=no; fi
  elif mod_has_hook setup; then
    setup='?'
  fi
  while IFS=$'\t' read -r src dst; do
    [[ -z $src ]] && continue
    ((l_total++))
    st=$(link_state "$src" "$dst")
    [[ $st == ok ]] && ((l_ok++))
    [[ $st == conflict || $st == foreign ]] && ((l_bad++))
  done < <(links_of "$name")
  printf '%s\n' "ok|$pk_ok|$pk_total|$setup|$l_ok|$l_total|$l_bad"
}
