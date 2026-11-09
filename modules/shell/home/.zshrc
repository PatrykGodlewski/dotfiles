#
# ~/.zshrc — the same on every distro
#
#   1. Omarchy        its environment, aliases and functions (only on Omarchy)
#   2. Shared         ~/.config/shell: env, aliases, functions (also used by bash)
#   3. Plugins        zinit
#   4. Completion
#   5. History
#   6. Prompt         oh-my-posh
#   7. Integrations   fzf, zoxide, bun

# ---- 1. Omarchy -------------------------------------------------------------
# Omarchy's envs, aliases and functions work in zsh; its bash-only init
# (mise, starship, zoxide hooks) is replaced by the zsh setup below.
if [[ -r /usr/share/omarchy/default/bash/env-bootstrap ]]; then
	source /usr/share/omarchy/default/bash/env-bootstrap
	for _part in envs aliases functions; do
		source "$OMARCHY_PATH/default/bash/$_part"
	done
	unset _part
	unalias cd 2>/dev/null # zoxide takes over `cd` in section 7
	command -v mise >/dev/null && eval "$(mise activate zsh)"
fi

# ---- 2. Shared --------------------------------------------------------------
for _part in env aliases functions; do
	[[ -r ~/.config/shell/$_part.sh ]] && source ~/.config/shell/$_part.sh
done
unset _part

# ---- 3. Plugins (zinit, installed on first start) ---------------------------
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -d $ZINIT_HOME ]]; then
	mkdir -p "${ZINIT_HOME:h}"
	git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "$ZINIT_HOME/zinit.zsh"

zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::command-not-found
command -v pacman >/dev/null && zinit snippet OMZP::archlinux
# zinit snippet OMZP::aws
# zinit snippet OMZP::kubectl
# zinit snippet OMZP::kubectx

# ---- 4. Completion ----------------------------------------------------------
autoload -Uz compinit && compinit
zinit cdreplay -q

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# ---- 5. History -------------------------------------------------------------
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory sharehistory
setopt hist_ignore_space hist_ignore_all_dups hist_save_no_dups hist_ignore_dups hist_find_no_dups

# ---- 6. Prompt --------------------------------------------------------------
if command -v oh-my-posh >/dev/null; then
	eval "$(oh-my-posh init zsh --config ~/.config/ohmyposh/base.omp.json)"
fi

# ---- 7. Integrations --------------------------------------------------------
# fzf key bindings: built in since fzf 0.48, else wherever the distro put them
if fzf --zsh >/dev/null 2>&1; then
	source <(fzf --zsh)
else
	for _f in /usr/share/fzf/key-bindings.zsh /usr/share/doc/fzf/examples/key-bindings.zsh; do
		[[ -r $_f ]] && source "$_f" && break
	done
	unset _f
fi
command -v zoxide >/dev/null && eval "$(zoxide init --cmd cd zsh)"
[[ -s $BUN_INSTALL/_bun ]] && source "$BUN_INSTALL/_bun"
