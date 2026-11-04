# shellcheck shell=bash
# OS detection. Sets:
#   OS_ID      e.g. arch, endeavouros, manjaro, ubuntu, debian, pop
#   OS_NAME    pretty name
#   OS_FAMILY  arch | debian | unknown
#   OS_WSL     1 when running under WSL
#   OS_TAGS    list used by ONLY_ON / SKIP_ON: family, id, and "wsl" when under WSL

detect_os() {
  local id='' like='' name='' rel=${DOT_OS_RELEASE:-/etc/os-release}  # override for tests
  if [[ -r $rel ]]; then
    # shellcheck disable=SC1090
    id=$(. "$rel" && echo "${ID:-}")
    like=$(. "$rel" && echo "${ID_LIKE:-}")
    name=$(. "$rel" && echo "${PRETTY_NAME:-$ID}")
  fi
  OS_ID=$id
  OS_NAME=${name:-unknown}
  case " $id $like " in
    *" arch "*) OS_FAMILY=arch ;;
    *" debian "* | *" ubuntu "*) OS_FAMILY=debian ;;
    *) OS_FAMILY=unknown ;;
  esac
  OS_WSL=0
  if [[ -n ${WSL_DISTRO_NAME:-} ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    OS_WSL=1
  fi
  [[ -n ${DOT_WSL:-} ]] && OS_WSL=$DOT_WSL   # override (e.g. docker on a WSL kernel)
  OS_TAGS=("$OS_FAMILY" "$OS_ID")
  [[ $OS_WSL == 1 ]] && OS_TAGS+=(wsl)
  export OS_ID OS_NAME OS_FAMILY OS_WSL
}

os_summary() {
  local s="$OS_NAME ($OS_FAMILY"
  [[ $OS_WSL == 1 ]] && s+=", WSL"
  printf '%s)' "$s"
}
