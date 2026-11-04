# shellcheck shell=bash disable=SC2034
DESC="Volta node version manager + latest node"
PKGS=(curl)

is_installed() { [[ -x $HOME/.volta/bin/volta ]]; }
setup() {
  # --skip-setup: don't let the installer edit the (symlinked) shell rc files
  run_sh 'curl -fsSL https://get.volta.sh | bash -s -- --skip-setup'
  run "$HOME/.volta/bin/volta" install node
}
