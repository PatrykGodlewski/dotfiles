# Environment shared by bash and zsh (POSIX sh) — sourced by ~/.bashrc and ~/.zshrc.

# Prepend a directory to PATH once, if it exists
path_prepend() {
	case ":$PATH:" in
		*":$1:"*) ;;
		*) [ -d "$1" ] && PATH="$1:$PATH" ;;
	esac
}

# ---- editor
if command -v nvim >/dev/null 2>&1; then
	export EDITOR=nvim VISUAL=nvim GIT_EDITOR=nvim
fi

# ---- machine settings written by dot (not in git): DOTS_PROJECT_ROOT, …
#      set with: dot projects <path>
[ -f "$HOME/.config/dotfiles/env.sh" ] && . "$HOME/.config/dotfiles/env.sh"
if [ -z "${DOTS_PROJECT_ROOT:-}" ]; then
	if [ -d "$HOME/Projects" ]; then DOTS_PROJECT_ROOT="$HOME/Projects"; else DOTS_PROJECT_ROOT="$HOME/projects"; fi
fi
export DOTS_PROJECT_ROOT

# ---- tools that live in $HOME
export BUN_INSTALL="$HOME/.bun"
export PNPM_HOME="$HOME/.local/share/pnpm"
export VOLTA_HOME="$HOME/.volta"

# ---- PATH (the last one added ends up first)
path_prepend /usr/local/go/bin
command -v go >/dev/null 2>&1 && path_prepend "$(go env GOPATH)/bin"
path_prepend "$HOME/personal/idea-UI/bin"
path_prepend "$HOME/.local/scripts"
path_prepend "$BUN_INSTALL/bin"
path_prepend "$VOLTA_HOME/bin"
path_prepend "$PNPM_HOME"
# ~/.local/bin always first, so `dot` isn't shadowed by graphviz's /usr/bin/dot
case ":$PATH:" in
	":$HOME/.local/bin:"*) ;;
	*) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH

# ---- machine secrets (not in git, see modules/secrets)
if [ -f "$HOME/.config/dotfiles/secrets.env" ]; then
	set -a
	. "$HOME/.config/dotfiles/secrets.env"
	set +a
fi
