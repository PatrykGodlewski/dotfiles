# shellcheck shell=bash disable=SC2034
# OpenRGB (https://openrgb.org): one app for RGB lighting across vendors.
# Arch: the package ships its udev rules. Elsewhere it's the flatpak, which
# can't install udev rules, so devices may need OpenRGB's 60-openrgb.rules.
# configure() loads i2c-dev at boot so RAM / motherboard RGB (SMBus) is found.
DESC="OpenRGB: RGB lighting control (pacman on Arch, flatpak elsewhere) + i2c-dev"
SKIP_ON=(wsl)
PACMAN=(openrgb i2c-tools)
if [[ $OS_FAMILY != arch ]]; then
  FLATPAK=(org.openrgb.OpenRGB)
fi

_OPENRGB_I2C=/etc/modules-load.d/i2c-dev.conf

configure() {
  [[ -f $_OPENRGB_I2C ]] || run_sh "echo i2c-dev | sudo tee $_OPENRGB_I2C >/dev/null"
  [[ -d /sys/module/i2c_dev ]] || as_root modprobe i2c-dev
  return 0
}

teardown() {
  [[ -f $_OPENRGB_I2C ]] && as_root rm -f "$_OPENRGB_I2C"
  return 0
}
