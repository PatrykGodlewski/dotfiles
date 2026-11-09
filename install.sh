#!/usr/bin/env bash
# Bootstrap dotfiles on a new or existing machine (Arch- or Debian/Ubuntu-based):
#
#   curl -fsSL https://raw.githubusercontent.com/PatrykGodlewski/dotfiles/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- configs   # only pick configs to copy/link
#   curl -fsSL .../install.sh | bash -s -- full      # core packages, then the dot menu
#
# Clones (or updates) the repo, puts `dot` on PATH ahead of anything else
# called `dot` (e.g. graphviz), then runs the chosen mode:
#   configs  pick configs to copy or link; installs no packages
#   full     install the core module (gum, build tools), open the dot menu
#   none     just install the `dot` command
# Without a mode it asks (default when there is no terminal: full).
#
# Env overrides: DOTFILES_DIR, DOTFILES_REPO, DOTFILES_BRANCH,
#                DOT_INSTALL=<mode>, DOT_NO_MENU=1 (don't open anything at the end)
#
# Everything is inside main() so a partially downloaded script never runs.

main() {
  set -euo pipefail
  local repo=${DOTFILES_REPO:-https://github.com/PatrykGodlewski/dotfiles.git}
  local branch=${DOTFILES_BRANCH:-main}
  local mode=${1:-${DOT_INSTALL:-}}

  say() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
  warn() { printf '\033[1;33m!\033[0m %s\n' "$*" >&2; }
  fail() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
  sudo_() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }
  has_tty() { { : </dev/tty; } 2>/dev/null; }

  case $mode in
    '' | configs | full | none) ;;
    *) fail "unknown mode '$mode' (use: configs | full | none)" ;;
  esac

  # Reuse an existing clone instead of making a second one.
  local dir=${DOTFILES_DIR:-}
  if [[ -z $dir ]]; then
    local d
    for d in "$HOME/Projects/dotfiles" "$HOME/projects/dotfiles"; do
      [[ -d $d/.git ]] && { dir=$d; break; }
    done
    dir=${dir:-$HOME/Projects/dotfiles}
  fi

  [[ -r /etc/os-release ]] || fail "cannot detect OS (/etc/os-release missing)"
  local id like
  id=$(. /etc/os-release && echo "${ID:-}")
  like=$(. /etc/os-release && echo "${ID_LIKE:-}")

  if ! command -v git >/dev/null || ! command -v curl >/dev/null; then
    say "Installing git and curl"
    case " $id $like " in
      *" arch "*) sudo_ pacman -Sy --needed --noconfirm git curl ;;
      *" debian "* | *" ubuntu "*)
        sudo_ apt-get update -qq
        sudo_ env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git curl ca-certificates
        ;;
      *) fail "unsupported distro '$id' — Arch- and Debian/Ubuntu-based only" ;;
    esac
  fi

  if [[ -d $dir/.git ]]; then
    say "Updating $dir"
    git -C "$dir" pull --ff-only || warn "could not fast-forward, keeping local state"
  else
    say "Cloning $repo → $dir"
    mkdir -p "$(dirname "$dir")"
    git clone --branch "$branch" "$repo" "$dir"
  fi

  # Put `dot` on PATH. ~/.local/bin must come FIRST: some distros append it
  # after /usr/bin, where graphviz ships its own `dot`.
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$dir/dot" "$HOME/.local/bin/dot"
  export PATH="$HOME/.local/bin:$PATH"
  local rc marker='# dotfiles: ~/.local/bin first'
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -f $rc ]] || continue
    [[ -L $rc ]] && continue # managed by the repo, which already handles PATH
    grep -qF "$marker" "$rc" && continue
    printf '\n%s (so `dot` is not shadowed by e.g. graphviz)\ncase ":$PATH:" in ":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac\n' \
      "$marker" >>"$rc"
    say "Added ~/.local/bin to the front of PATH in ${rc/#$HOME/\~}"
  done
  if [[ -x /usr/bin/dot && $(readlink -f /usr/bin/dot) != "$(readlink -f "$dir/dot")" ]]; then
    warn "/usr/bin/dot (graphviz) exists — in already open shells run: exec \$SHELL -l"
  fi

  if [[ -z $mode ]]; then
    if has_tty && [[ -z ${DOT_NO_MENU:-} ]]; then
      printf '\nWhat now?\n  1) configs — pick configs to copy/link, no packages (default)\n  2) full    — install core packages, then open the dot menu\n  3) none    — just install the dot command\n'
      local a
      read -rp "Choose [1-3]: " a </dev/tty
      case $a in 2) mode=full ;; 3) mode=none ;; *) mode=configs ;; esac
    else
      mode=full
    fi
  fi

  if [[ $mode == full ]]; then
    say "Installing core (gum, build tools)"
    "$dir/dot" bootstrap </dev/null
  fi

  say "Done. Repo: $dir   command: ~/.local/bin/dot"
  if [[ $mode == none || -n ${DOT_NO_MENU:-} ]] || ! has_tty; then
    say "Next: dot configs   (copy/link configs)   or   dot   (menu)"
    return 0
  fi
  case $mode in
    configs) exec "$dir/dot" configs </dev/tty ;;
    full) exec "$dir/dot" </dev/tty ;;
  esac
}

main "$@"
