# shellcheck shell=bash disable=SC2034
# Module: __NAME__
# Config files: put them in ./home/ mirroring $HOME, e.g. home/.config/__NAME__/
# They get symlinked on `dot apply`. Or use: dot adopt ~/.config/__NAME__ __NAME__
# This file is plain bash: you can use if/case on $OS_FAMILY (arch|debian), $OS_ID, $OS_WSL.

DESC="__DESC__"

# Packages ------------------------------------------------------------------
PKGS=(__PKGS__)        # same name on Arch and Ubuntu (pacman / apt)
PACMAN=(__PACMAN__)    # Arch only
APT=(__APT__)          # Ubuntu/Debian only
# AUR=()               # Arch AUR via yay (bootstrapped automatically)
# CARGO=()             # cargo install
# FLATPAK=()           # flathub app ids
# SERVICES=()          # systemd units: enable --now

# Rules ---------------------------------------------------------------------
# DEPENDS=()           # modules installed before this one
# ONLY_ON=(arch)       # tags: arch debian ubuntu wsl ...
# SKIP_ON=(wsl)

# Hooks (delete what you don't need) ----------------------------------------
# is_installed() { has __NAME__; }          # lets setup() be skipped
# setup() {                                  # custom install (curl, release binary, build)
#   gh_install_bin owner/repo "linux_$(goarch)\.tar\.gz$" __NAME__
#   run_sh 'curl -fsSL https://example.com/install.sh | bash'
# }
# configure() { :; }                         # every apply, after linking (idempotent)
# teardown() { :; }                          # on `dot remove __NAME__`
