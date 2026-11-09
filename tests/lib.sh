# shellcheck shell=bash
# Test harness for dot. Every test runs in a subshell with:
#   - its own $HOME   ($T/home)
#   - a fixture repo  ($R) with the real dot + lib/ + templates/, but FAKE
#     package managers that record installs in $FAKE_DB instead of touching
#     the system
#   - a fake /etc/os-release (use_os arch|ubuntu|...)

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

new_sandbox() { # expects $T (created by the runner)
  export HOME="$T/home"
  mkdir -p "$HOME"
  unset XDG_CONFIG_HOME XDG_STATE_HOME XDG_DATA_HOME WSL_DISTRO_NAME
  export NO_COLOR=1 DOT_NO_GUM=1 DOT_WSL=0
  export OMARCHY_PATH="$T/omshare" # never read the host's Omarchy data
  unset DOT_OMARCHY DOT_FORCE_TTY
  export FAKE_DB="$T/fake-db" FAKE_LOG="$T/fake-log"
  : >"$FAKE_DB"; : >"$FAKE_LOG"
  unset FAKE_FAIL FAKE_UNAVAILABLE
  install_traps
  R="$T/repo"
  mkdir -p "$R/modules" "$R/presets" "$R/managers"
  cp -r "$REPO/dot" "$REPO/lib" "$REPO/cmd" "$REPO/templates" "$R/"
  fake_manager pacman PACMAN arch
  fake_manager apt APT debian
  fake_manager extra EXTRA ''
  use_os arch
  SEL="$HOME/.config/dotfiles/selected"
  REC="$HOME/.local/state/dotfiles/installed"
}

# Every command that could touch the real system resolves to a trap that logs
# the call to $T/traps.log and fails. tests/run.sh fails any test that hit one.
# Tests that need such a command install a fake into $T/bin (searched first).
TRAPPED_CMDS=(omarchy sudo pkexec pacman yay paru makepkg apt apt-get dpkg flatpak
  cargo rustup systemctl xdg-settings xdg-mime gum curl wget hyprctl notify-send
  omarchy-pkg-defaults)
install_traps() {
  mkdir -p "$T/traps" "$T/bin"
  local c
  for c in "${TRAPPED_CMDS[@]}"; do
    printf '#!/bin/sh\necho "%s $*" >>"%s/traps.log"\nexit 97\n' "$c" "$T" >"$T/traps/$c"
    chmod +x "$T/traps/$c"
  done
  export PATH="$T/bin:$T/traps:$PATH"
}

# fake_cmd <name> <<'EOF' ... script body ... EOF   (a stand-in in $T/bin)
fake_cmd() { { echo '#!/usr/bin/env bash'; cat; } >"$T/bin/$1"; chmod +x "$T/bin/$1"; }

# fake_manager <name> <MODULE_VAR> <family|''>
fake_manager() {
  cat >"$R/managers/$1.sh" <<EOF
M_DESC="fake $1"
M_VAR=$2
M_FAMILY=$3
_fake_add() { local p; for p in "\$@"; do echo "$1 \$p" >>"\$FAKE_DB"; done; }
_fake_del() { local p; for p in "\$@"; do grep -vx "$1 \$p" "\$FAKE_DB" >"\$FAKE_DB.t"; mv "\$FAKE_DB.t" "\$FAKE_DB"; done; }
m_available() { [[ "\${FAKE_UNAVAILABLE:-}" != "$1" ]] && { [[ -z "$3" ]] || [[ \$OS_FAMILY == "$3" ]]; }; }
m_ensure() { echo "ensure $1" >>"\$FAKE_LOG"; }
m_has() { grep -qx "$1 \$1" "\$FAKE_DB"; }
m_install() {
  local p
  for p in "\$@"; do [[ \$p == "\${FAKE_FAIL:-}" ]] && return 1; done
  echo "install $1 \$*" >>"\$FAKE_LOG"
  run _fake_add "\$@"
}
m_remove() { echo "remove $1 \$*" >>"\$FAKE_LOG"; run _fake_del "\$@"; }
EOF
}

use_os() {
  local f="$T/os-release"
  case $1 in
    arch) printf 'ID=arch\nPRETTY_NAME="Arch Linux"\n' >"$f" ;;
    endeavouros) printf 'ID=endeavouros\nID_LIKE=arch\nPRETTY_NAME="EndeavourOS"\n' >"$f" ;;
    manjaro) printf 'ID=manjaro\nID_LIKE=arch\nPRETTY_NAME="Manjaro"\n' >"$f" ;;
    ubuntu) printf 'ID=ubuntu\nID_LIKE=debian\nPRETTY_NAME="Ubuntu 24.04"\n' >"$f" ;;
    debian) printf 'ID=debian\nPRETTY_NAME="Debian 12"\n' >"$f" ;;
    pop) printf 'ID=pop\nID_LIKE="ubuntu debian"\nPRETTY_NAME="Pop!_OS"\n' >"$f" ;;
    fedora) printf 'ID=fedora\nPRETTY_NAME="Fedora"\n' >"$f" ;;
  esac
  export DOT_OS_RELEASE=$f
}

# mkmod <name> <<'EOF' ... module.sh body ... EOF
mkmod() { mkdir -p "$R/modules/$1"; cat >"$R/modules/$1/module.sh"; }
# mkhome <module> <path-under-home> [content]
mkhome() {
  local f="$R/modules/$1/home/$2"
  mkdir -p "$(dirname "$f")"
  printf '%s\n' "${3:-content of $2}" >"$f"
}
mkpreset() { local n=$1; shift; printf '%s\n' "$@" >"$R/presets/$n"; }
preinstall() { local m=$1; shift; local p; for p in "$@"; do echo "$m $p" >>"$FAKE_DB"; done; }

# Run the CLI non-interactively; output in $OUT, status in $RC
dotx() { OUT=$("$R/dot" "$@" </dev/null 2>&1); RC=$?; }
# Run it "interactively": plain prompts read answers from $1 (one per line)
doti() { local input=$1; shift; OUT=$(printf '%s\n' "$input" | DOT_FORCE_TTY=1 "$R/dot" "$@" 2>&1); RC=$?; }

# Source the libraries for unit tests
load_libs() {
  export DOT_ROOT=$R
  local f
  for f in core os ui managers state links modules github profile omarchy sync; do
    # shellcheck disable=SC1090
    source "$R/lib/$f.sh"
  done
  detect_os
  managers_load
}

# ---------------------------------------------------------------- asserts
_fail() { printf '    ASSERT FAILED: %s\n' "$*" >&2; [[ -n ${OUT:-} ]] && printf '    --- last output ---\n%s\n' "$OUT" | sed 's/^/    /' >&2; exit 1; }
assert_eq() { [[ $1 == "$2" ]] || _fail "${3:-} expected [$1] got [$2]"; }
assert_contains() { [[ $1 == *"$2"* ]] || _fail "${3:-} expected to contain [$2]"; }
assert_not_contains() { [[ $1 != *"$2"* ]] || _fail "${3:-} expected NOT to contain [$2]"; }
assert_ok() { [[ $RC -eq 0 ]] || _fail "${1:-command} exited $RC"; }
assert_rc_fail() { [[ $RC -ne 0 ]] || _fail "${1:-command} should have failed"; }
assert_link() { [[ -L $1 && $(readlink "$1") == "$2" ]] || _fail "$1 should link to $2 (is: $(readlink "$1" 2>/dev/null || echo none))"; }
assert_file() { [[ -e $1 ]] || _fail "$1 should exist"; }
assert_no_file() { [[ ! -e $1 && ! -L $1 ]] || _fail "$1 should not exist"; }
assert_line() { grep -qx -- "$2" "$1" 2>/dev/null || _fail "$1 should contain line [$2] (has: $(tr '\n' '|' <"$1" 2>/dev/null))"; }
assert_no_line() { ! grep -qx -- "$2" "$1" 2>/dev/null || _fail "$1 should NOT contain line [$2]"; }
