#!/usr/bin/env bash
# Bootstrap for a fresh machine (Arch- or Debian/Ubuntu-based):
#
#   curl -fsSL https://raw.githubusercontent.com/PatrykGodlewski/dotfiles/main/install.sh | bash
#
# Installs git/curl, clones the repo, puts `dot` on PATH, installs the core
# module (gum etc.), then opens the interactive `dot` menu.
# Env overrides: DOTFILES_DIR, DOTFILES_REPO, DOTFILES_BRANCH, DOT_NO_MENU=1
#
# Everything is inside main() so a partially downloaded script never runs.

main() {
  set -euo pipefail
  local repo=${DOTFILES_REPO:-https://github.com/PatrykGodlewski/dotfiles.git}
  local dir=${DOTFILES_DIR:-$HOME/projects/dotfiles}
  local branch=${DOTFILES_BRANCH:-main}

  say() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
  fail() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
  sudo_() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }

  [[ -r /etc/os-release ]] || fail "cannot detect OS (/etc/os-release missing)"
  local id like
  id=$(. /etc/os-release && echo "${ID:-}")
  like=$(. /etc/os-release && echo "${ID_LIKE:-}")

  say "Installing git and curl"
  case " $id $like " in
    *" arch "*) sudo_ pacman -Sy --needed --noconfirm git curl ;;
    *" debian "* | *" ubuntu "*)
      sudo_ apt-get update -qq
      sudo_ env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git curl ca-certificates
      ;;
    *) fail "unsupported distro '$id' — Arch- and Debian/Ubuntu-based only" ;;
  esac

  if [[ -d $dir/.git ]]; then
    say "Updating $dir"
    git -C "$dir" pull --ff-only || say "could not fast-forward, keeping local state"
  else
    say "Cloning $repo → $dir"
    mkdir -p "$(dirname "$dir")"
    git clone --branch "$branch" "$repo" "$dir"
  fi

  mkdir -p "$HOME/.local/bin"
  ln -sfn "$dir/dot" "$HOME/.local/bin/dot"
  export PATH="$HOME/.local/bin:$PATH"

  say "Installing core (gum, build tools)"
  "$dir/dot" bootstrap </dev/null

  say "Done. 'dot' is in ~/.local/bin (open a new shell if it's not on PATH yet)."
  if [[ -z ${DOT_NO_MENU:-} ]] && { : </dev/tty; } 2>/dev/null; then
    exec "$dir/dot" </dev/tty
  else
    say "Next: dot preset   (or: dot help)"
  fi
}

main "$@"
