# shellcheck shell=bash
# Core helpers: output, dry-run aware command execution, small utilities.

DOT_DRY=${DOT_DRY:-0}
DOT_YES=${DOT_YES:-0}
DOT_VERBOSE=${DOT_VERBOSE:-0}
DOT_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
DOT_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
  C_RESET=$'\e[0m' C_BOLD=$'\e[1m' C_DIM=$'\e[2m'
  C_RED=$'\e[31m' C_GREEN=$'\e[32m' C_YELLOW=$'\e[33m'
  C_BLUE=$'\e[34m' C_MAGENTA=$'\e[35m' C_CYAN=$'\e[36m'
else
  C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_MAGENTA='' C_CYAN=''
fi
export C_RESET C_BOLD C_DIM C_RED C_GREEN C_YELLOW C_BLUE C_MAGENTA C_CYAN

info() { printf '%s•%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()   { printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()  { err "$*"; exit 1; }

header() {
  printf '\n%s%s━━ %s %s%s\n' "$C_BOLD" "$C_MAGENTA" "$*" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$C_RESET"
}

# Run a command (argv form). In dry-run mode only print it.
run() {
  if [[ $DOT_DRY == 1 ]]; then
    printf '  %s[dry]%s %s\n' "$C_DIM" "$C_RESET" "$*"
    return 0
  fi
  printf '  %s$ %s%s\n' "$C_DIM" "$*" "$C_RESET"
  "$@"
}

# Run a shell snippet (string form), e.g. pipes: run_sh 'curl ... | bash'
run_sh() {
  if [[ $DOT_DRY == 1 ]]; then
    printf '  %s[dry]%s %s\n' "$C_DIM" "$C_RESET" "$1"
    return 0
  fi
  printf '  %s$ %s%s\n' "$C_DIM" "$1" "$C_RESET"
  bash -c "$1"
}

# Run as root: plain when already root, sudo otherwise.
as_root() {
  if [[ $EUID -eq 0 ]]; then run "$@"; else run sudo "$@"; fi
}

has() { command -v "$1" >/dev/null 2>&1; }

# "~/x" pretty path
pretty() { printf '%s' "${1/#$HOME/\~}"; }

# version_ge 0.11.2 0.10  -> true when $1 >= $2
version_ge() {
  [[ -n $1 ]] || return 1
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]
}

# x86_64 / arm64 naming used by most GitHub release assets
goarch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo x86_64 ;;
    aarch64 | arm64) echo arm64 ;;
    *) uname -m ;;
  esac
}

in_list() { # in_list needle item...
  local n=$1; shift
  local i
  for i in "$@"; do [[ $i == "$n" ]] && return 0; done
  return 1
}

# Per-invocation scratch dir
DOT_RUN_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dot.XXXXXX")
export DOT_RUN_DIR
trap 'rm -rf "$DOT_RUN_DIR"' EXIT
