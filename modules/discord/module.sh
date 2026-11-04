# shellcheck shell=bash disable=SC2034
DESC="Discord (pacman on Arch, flatpak elsewhere)"
SKIP_ON=(wsl)
PACMAN=(discord)
if [[ $OS_FAMILY != arch ]]; then
  FLATPAK=(com.discordapp.Discord)
fi
