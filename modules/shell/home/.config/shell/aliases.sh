# Aliases shared by bash and zsh — sourced by ~/.bashrc and ~/.zshrc.
# On Omarchy its own aliases are loaded first (ls → eza, …); these add to them.

# ---- everyday
alias c='clear'
alias ts='tmux-sessionizer'
alias grep='grep --color=auto'
if command -v nvim >/dev/null 2>&1; then
	alias vim='nvim'
	alias vi='nvim'
fi

# ---- ls (colors, short forms); on Omarchy `ls` stays its eza alias
command -v dircolors >/dev/null 2>&1 && eval "$(dircolors -b)"
[ -z "${OMARCHY_PATH:-}" ] && alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# ---- notify when a long command finishes:  sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history | tail -n1 | sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
