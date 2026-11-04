# shellcheck shell=bash disable=SC2034
DESC="lazygit terminal UI + config"
PACMAN=(lazygit)

is_installed() { has lazygit; }
setup() {
  gh_install_bin jesseduffield/lazygit "linux_$(goarch)\.tar\.gz$" lazygit
}
