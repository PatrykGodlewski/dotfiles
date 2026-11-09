# shellcheck shell=bash disable=SC2034
DESC="Hyprland desktop + everything hyprland.conf launches"
ONLY_ON=(arch)
SKIP_ON=(wsl omarchy) # Omarchy ships and manages its own Hyprland setup
DEPENDS=(kitty waybar wofi fonts)
PACMAN=(
  hyprland hyprpaper uwsm xdg-desktop-portal-hyprland
  wl-clipboard hyprshot
  polkit-kde-agent network-manager-applet
  wireplumber brightnessctl playerctl
  dolphin firefox
)
