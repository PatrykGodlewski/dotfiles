# shellcheck shell=bash disable=SC2034
DESC="Go toolchain (pacman on Arch, official tarball in /usr/local/go elsewhere)"
PKGS=(curl tar)
PACMAN=(go)   # Ubuntu's golang-go lags behind -> go.dev tarball in setup()

is_installed() { has go || [[ -x /usr/local/go/bin/go ]]; }
setup() {
  [[ $OS_FAMILY == arch ]] && return 0
  local arch ver
  case "$(uname -m)" in
    x86_64 | amd64) arch=amd64 ;;
    aarch64 | arm64) arch=arm64 ;;
    *) die "golang: unsupported arch $(uname -m)" ;;
  esac
  ver=$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1)
  [[ -n $ver ]] || die "golang: could not fetch latest version"
  as_root rm -rf /usr/local/go
  run_sh "curl -fsSL 'https://go.dev/dl/$ver.linux-$arch.tar.gz' | sudo tar -C /usr/local -xzf -"
}
