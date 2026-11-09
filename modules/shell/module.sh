# shellcheck shell=bash disable=SC2034
# bash + zsh, the same on every distro (Omarchy, Arch, Ubuntu/Debian):
#   ~/.config/shell/{env,aliases,functions}.sh   shared by both shells
#   ~/.bashrc   the distro's default .bashrc, then the shared files
#   ~/.zshrc    Omarchy's setup (on Omarchy), shared files, zinit, oh-my-posh
# setup() installs oh-my-posh and makes zsh the login shell.
DESC="bash + zsh for any distro: shared env/aliases/functions, zinit, oh-my-posh, zsh as login shell"
PKGS=(bash zsh git curl unzip fzf zoxide)

_shell_has_omp() { has oh-my-posh || [[ -x $HOME/.local/bin/oh-my-posh ]]; }
_shell_zsh_is_login() { [[ $(getent passwd "$(id -un)" | cut -d: -f7) == */zsh ]]; }

is_installed() { _shell_has_omp && _shell_zsh_is_login; }
setup() {
  _shell_has_omp || run_sh 'curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"'
  if ! _shell_zsh_is_login; then
    if [[ -t 0 ]]; then
      run chsh -s "$(command -v zsh)" # asks for your password; log out and in afterwards
    else
      warn "make zsh your login shell: chsh -s $(command -v zsh)"
    fi
  fi
}
