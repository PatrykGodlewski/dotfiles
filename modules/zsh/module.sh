# shellcheck shell=bash disable=SC2034
DESC="zsh + zinit plugins, oh-my-posh prompt, zoxide, fzf"
PKGS=(zsh zoxide fzf git)

is_installed() { has oh-my-posh || [[ -x $HOME/.local/bin/oh-my-posh ]]; }
setup() {
  run_sh 'curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"'
}
