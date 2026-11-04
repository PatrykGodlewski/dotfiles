# shellcheck shell=bash disable=SC2034
DESC="Neovim (latest) + config, ripgrep, fd, compilers for treesitter"
PKGS=(ripgrep gcc make unzip git curl)
PACMAN=(neovim fd)
APT=(fd-find)   # Ubuntu's neovim is too old -> release tarball in setup()

is_installed() {
  local v
  v=$(nvim --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')
  version_ge "$v" 0.11
}
setup() {
  gh_install_tree neovim/neovim "nvim-linux-$(goarch)\.tar\.gz$" nvim
}
