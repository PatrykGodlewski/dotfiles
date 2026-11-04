# shellcheck shell=bash
# Flatpak apps from Flathub (user install). Module variable: FLATPAK=(...)
M_DESC="Flatpak apps (flathub, --user)"
M_VAR=FLATPAK

m_available() { true; }
m_ensure() {
  has flatpak || native_install flatpak || return 1
  run flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}
m_has() { has flatpak && flatpak info "$1" >/dev/null 2>&1; }
m_install() { run flatpak install --user -y --noninteractive flathub "$@"; }
m_remove() { run flatpak uninstall --user -y "$@"; }
