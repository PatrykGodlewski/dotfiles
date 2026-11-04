# shellcheck shell=bash disable=SC2034
DESC="Bluetooth stack (bluez) + service"
SKIP_ON=(wsl)
PACMAN=(bluez bluez-utils)
APT=(bluez)
SERVICES=(bluetooth)
