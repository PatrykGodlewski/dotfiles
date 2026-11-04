#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PS1='[\u@\h \W]\$ '

case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

if [[ -f "$HOME/.bash_aliases" ]]; then
	source "$HOME/.bash_aliases"
fi

command -v zsh >/dev/null && exec zsh
