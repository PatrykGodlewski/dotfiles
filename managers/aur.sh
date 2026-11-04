# shellcheck shell=bash
# Arch User Repository via yay (bootstrapped from yay-bin if missing). Module variable: AUR=(...)
M_DESC="AUR packages (yay)"
M_VAR=AUR
M_FAMILY=arch

m_available() { [[ $OS_FAMILY == arch ]]; }
m_ensure() {
  has yay && return 0
  [[ $EUID -eq 0 ]] && { err "makepkg cannot run as root — run dot as a normal user"; return 1; }
  info "Installing yay (AUR helper)"
  as_root pacman -S --needed --noconfirm git base-devel || return 1
  local tmp="$DOT_RUN_DIR/yay-bin"
  run git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp" || return 1
  run_sh "cd '$tmp' && makepkg -si --noconfirm"
}
m_has() { pacman -T "$1" >/dev/null 2>&1; }
m_install() { run yay -S --needed --noconfirm "$@"; }
m_remove() { run yay -Rns --noconfirm "$@"; }
