#!/usr/bin/env bash
# Install the `dot` command from your dotfiles clone. Nothing else: no
# cloning, no pulling, no packages, no configs.
#
#   ~/Projects/dotfiles/install.sh        # run from the clone, or:
#   curl -fsSL https://raw.githubusercontent.com/PatrykGodlewski/dotfiles/main/install.sh | bash
#     (uses $DOTFILES_DIR, ~/Projects/dotfiles or ~/projects/dotfiles)
#
# Links ~/.local/bin/dot -> <clone>/dot and makes sure ~/.local/bin comes
# first in PATH (graphviz ships its own /usr/bin/dot).
# Everything is inside main() so a partially downloaded script never runs.

main() {
  set -euo pipefail

  is_clone() { [[ -n $1 && -x $1/dot && -d $1/lib ]]; }

  local dir='' d rc marker script
  script=${BASH_SOURCE[0]:-}
  [[ -f $script ]] && dir=$(cd "$(dirname "$script")" && pwd) # run from a clone
  if ! is_clone "$dir"; then                                  # piped through curl
    dir=''
    for d in "${DOTFILES_DIR:-}" "$HOME/Projects/dotfiles" "$HOME/projects/dotfiles"; do
      is_clone "$d" && { dir=$d; break; }
    done
  fi
  if [[ -z $dir ]]; then
    echo "error: no dotfiles clone found. Clone it first, then run this again:" >&2
    echo "  git clone https://github.com/PatrykGodlewski/dotfiles ~/Projects/dotfiles" >&2
    exit 1
  fi

  mkdir -p "$HOME/.local/bin"
  ln -sfn "$dir/dot" "$HOME/.local/bin/dot"
  echo "✓ ~/.local/bin/dot → ${dir/#$HOME/\~}/dot"

  # ~/.local/bin first in PATH, for new shells
  marker='# dotfiles: ~/.local/bin first'
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -f $rc && ! -L $rc ]] || continue # a symlinked rc comes from the repo, which handles PATH
    grep -qF "$marker" "$rc" && continue
    printf '\n%s (so `dot` is not shadowed by e.g. graphviz)\ncase ":$PATH:" in ":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac\n' \
      "$marker" >>"$rc"
    echo "✓ ~/.local/bin added to the front of PATH in ${rc/#$HOME/\~}"
  done

  # Only this terminal can be stale: say so when `dot` doesn't resolve to ours yet
  if [[ $(command -v dot 2>/dev/null) != "$HOME/.local/bin/dot" ]]; then
    echo "→ open a new terminal (or run: exec \$SHELL -l), then: dot"
  else
    echo "→ next: dot"
  fi
}

main "$@"
