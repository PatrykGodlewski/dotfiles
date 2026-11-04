# shellcheck shell=bash
# Arch official repos. Module variable: PACMAN=(...) — also receives PKGS on Arch.
M_DESC="Arch packages (pacman)"
M_VAR=PACMAN
M_FAMILY=arch   # ignored silently on other distro families

m_available() { [[ $OS_FAMILY == arch ]] && has pacman; }
m_ensure() { :; }
m_has() { pacman -T "$1" >/dev/null 2>&1; }
m_install() {
  # Sync + full upgrade once per run (Arch does not support partial upgrades).
  if [[ ! -e $DOT_RUN_DIR/pacman-synced ]]; then
    touch "$DOT_RUN_DIR/pacman-synced"
    as_root pacman -Syu --needed --noconfirm "$@"
  else
    as_root pacman -S --needed --noconfirm "$@"
  fi
}
m_remove() { as_root pacman -Rns --noconfirm "$@"; }
