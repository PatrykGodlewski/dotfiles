# shellcheck shell=bash disable=SC2034
# Vesktop (https://vesktop.dev): Discord client with Vencord built in.
# Its own app (not a patched Discord), so Discord updates can't break it.
DESC="Vesktop: Discord client with Vencord built in (AUR on Arch, flatpak elsewhere)"
SKIP_ON=(wsl)
AUR=(vesktop-bin)
if [[ $OS_FAMILY != arch ]]; then
  FLATPAK=(dev.vencord.Vesktop)
fi
