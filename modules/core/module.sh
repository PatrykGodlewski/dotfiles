# shellcheck shell=bash disable=SC2034
# Always installed: what dot itself (and most modules) need.
DESC="Base tools dot needs: git, curl, unzip, build tools, gum"
REQUIRED=1
PKGS=(git curl wget unzip tar less)
PACMAN=(base-devel man-db gum)
APT=(build-essential ca-certificates man-db)

is_installed() { has gum; }
setup() {
  # Ubuntu has no gum package: use the GitHub release binary
  gh_install_bin charmbracelet/gum "Linux_$(goarch)\.tar\.gz$" gum
}
