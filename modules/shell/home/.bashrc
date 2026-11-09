#
# ~/.bashrc — the same on every distro
#
# zsh is the login shell (set by `dot apply shell`); bash is still used by
# scripts and when started by hand, so it gets the same environment.

# 1. The distro's own default .bashrc: Omarchy's setup on Omarchy;
#    history, colors and completion on Ubuntu/Debian; a prompt on Arch.
[[ -r /etc/skel/.bashrc ]] && source /etc/skel/.bashrc

# Non-interactive shells stop here
[[ $- != *i* ]] && return

# 2. Shared environment, aliases and functions
for _part in env aliases functions; do
	[[ -r ~/.config/shell/$_part.sh ]] && source ~/.config/shell/$_part.sh
done
unset _part
