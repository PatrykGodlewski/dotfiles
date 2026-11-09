# shellcheck shell=bash
# Package manager registry. Each managers/<name>.sh defines:
#   M_DESC, M_VAR (module variable it reads, e.g. PACMAN), optional M_FAMILY
#   (arch|debian: manager only exists there and is silently ignored elsewhere)
#   m_available  m_ensure  m_has <pkg>  m_install <pkgs...>  m_remove <pkgs...>
# Manager files run in a subshell so their functions never leak.

declare -gA MGR_VAR=() MGR_DESC=() MGR_FAMILY=()
declare -ga MGR_ORDER=()

managers_load() {
  local preferred=(pacman apt aur cargo flatpak) f n
  local -a found=()
  for f in "$DOT_HOME"/managers/*.sh; do found+=("$(basename "$f" .sh)"); done
  for n in "${preferred[@]}"; do in_list "$n" "${found[@]}" && MGR_ORDER+=("$n"); done
  for n in "${found[@]}"; do
    in_list "$n" "${preferred[@]}" services || MGR_ORDER+=("$n")
  done
  in_list services "${found[@]}" && MGR_ORDER+=(services)
  for n in "${MGR_ORDER[@]}"; do
    MGR_VAR[$n]=$(M_VAR='' && source "$DOT_HOME/managers/$n.sh" && echo "$M_VAR")
    MGR_DESC[$n]=$(M_DESC='' && source "$DOT_HOME/managers/$n.sh" && echo "$M_DESC")
    MGR_FAMILY[$n]=$(M_FAMILY='' && source "$DOT_HOME/managers/$n.sh" && echo "$M_FAMILY")
  done
}

# mgr <manager> <function> [args...]
mgr() {
  local n=$1 fn=$2; shift 2
  (
    set +e # managers check return codes themselves; don't inherit setup()'s set -e
    # shellcheck disable=SC1090
    source "$DOT_HOME/managers/$n.sh" && "$fn" "$@"
  )
}

native_manager() {
  case $OS_FAMILY in
    arch) echo pacman ;;
    debian) echo apt ;;
  esac
}

# Install with the distro's own package manager (used by manager bootstraps).
native_install() {
  local n; n=$(native_manager)
  [[ -n $n ]] || { err "no native package manager for $OS_FAMILY"; return 1; }
  mgr "$n" m_install "$@"
}

# Is this manager relevant on this OS at all? (family-bound managers aren't)
mgr_relevant() {
  local f=${MGR_FAMILY[$1]:-}
  [[ -z $f || $f == "$OS_FAMILY" ]]
}
