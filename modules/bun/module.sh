# shellcheck shell=bash disable=SC2034
DESC="Bun JavaScript runtime (~/.bun)"
PKGS=(unzip curl)

is_installed() { [[ -x $HOME/.bun/bin/bun ]]; }
setup() {
  # SHELL=/bin/sh stops the installer from editing the (symlinked) ~/.zshrc
  run_sh 'curl -fsSL https://bun.sh/install | SHELL=/bin/sh bash'
}
