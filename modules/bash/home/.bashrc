#
# ~/.bashrc — works on its own and on Omarchy
#

# Omarchy: its environment (OMARCHY_PATH, PATH) is needed even in non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# If not running interactively, don't do anything else
[[ $- != *i* ]] && return

if [[ -n ${OMARCHY_PATH:-} && -r $OMARCHY_PATH/default/bash/rc ]]; then
	# Omarchy's prompt, aliases, functions and tools; everything below adds to / overrides them
	source "$OMARCHY_PATH/default/bash/rc"
else
	PS1='[\u@\h \W]\$ '
fi

# ~/.local/bin first, so `dot` is not shadowed by graphviz's /usr/bin/dot
case ":$PATH:" in ":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

if [[ -f "$HOME/.bash_aliases" ]]; then
	source "$HOME/.bash_aliases"
fi

# Hand over to zsh when it's installed — except on Omarchy, which is built around bash
if [[ -z ${OMARCHY_PATH:-} ]] && command -v zsh >/dev/null; then
	exec zsh
fi
