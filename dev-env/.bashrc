#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PS1='[\u@\h \W]\$ '

if [[ -f "$HOME/.bash_aliases" ]]; then
	source "$HOME/.bash_aliases"
fi

exec zsh
