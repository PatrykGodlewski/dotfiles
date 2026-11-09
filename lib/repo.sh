# shellcheck shell=bash
# Where things live. dot keeps two things apart:
#   DOT_HOME  the tool: lib/ cmd/ managers/ templates/
#             ~/.local/share/dot when installed, or the checkout dot runs from
#   DOT_ROOT  your dotfiles repo: modules/ presets/ sync.ignore
#             found by repo_find; empty when there is none (yet)

REPO_FILE="$DOT_CONFIG_DIR/repo"

is_dotfiles_repo() { [[ -n $1 && -d $1/modules ]]; }

# repo_find -> "path<TAB>how it was found" of the first match:
#   $DOTFILES_DIR, `dot repo <path>`, the checkout dot runs from, the current
#   directory, then ~/Projects/dotfiles ~/projects/dotfiles ~/dotfiles ~/.dotfiles
repo_find() {
  local saved='' d how
  [[ -f $REPO_FILE ]] && read -r saved <"$REPO_FILE"
  local -a cand=(
    "${DOTFILES_DIR:-}"$'\t'"\$DOTFILES_DIR"
    "$saved"$'\t'"set with 'dot repo'"
    "$DOT_HOME"$'\t'"the checkout dot runs from"
    "$PWD"$'\t'"current directory"
    "$HOME/Projects/dotfiles"$'\t'"default location"
    "$HOME/projects/dotfiles"$'\t'"default location"
    "$HOME/dotfiles"$'\t'"default location"
    "$HOME/.dotfiles"$'\t'"default location"
  )
  local c
  for c in "${cand[@]}"; do
    d=${c%%$'\t'*} how=${c#*$'\t'}
    is_dotfiles_repo "$d" && { printf '%s\t%s\n' "$(cd "$d" && pwd)" "$how"; return 0; }
  done
  return 1
}

repo_require() {
  [[ -n $DOT_ROOT ]] && return 0
  err "no dotfiles repo found (a directory with modules/)."
  printf '  Clone yours, e.g.  git clone https://github.com/PatrykGodlewski/dotfiles ~/Projects/dotfiles\n' >&2
  printf '  (found there automatically), or point dot at it:  dot repo /path/to/clone\n' >&2
  exit 1
}
