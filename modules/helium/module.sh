# shellcheck shell=bash disable=SC2034
# Helium (https://helium.computer): private, Chromium-based browser.
# Installed straight from the official releases (github.com/imputnet/helium-linux),
# the same way on every distro, without root:
#   ~/.local/opt/helium/              the release, as published
#   ~/.local/bin/helium               command
#   ~/.local/share/applications/      launcher entry (+ icon)
# Downloads are checked against Helium's signing key when gpg is available.
# `dot apply helium` updates it whenever a newer release is out.
# Removing it (dot remove helium) keeps your profile in ~/.config/net.imput.helium.
DESC="Helium browser (helium.computer), official release; dot apply updates it"
SKIP_ON=(wsl)             # on WSL, install browsers on the Windows side

# Make Helium the default browser (links; on Omarchy also Super+B and web apps).
# 0 = leave the default browser alone.
HELIUM_DEFAULT_BROWSER=1

PKGS=(curl tar)           # to fetch, unpack and verify the release:
PACMAN=(xz gnupg)
APT=(xz-utils gnupg)

_HELIUM_REPO=imputnet/helium-linux
_HELIUM_KEY=BE677C1989D35EAB2C5F26C9351601AD01D6378E # Helium signing key <helium@imput.net>
_HELIUM_DIR="$HOME/.local/opt/helium"
_HELIUM_APP="$HOME/.local/share/applications/helium.desktop"
_HELIUM_ICON="$HOME/.local/share/icons/hicolor/256x256/apps/helium.png"

# newest release tag, e.g. 0.21.1.1
_helium_latest() {
  curl -fsSL "https://api.github.com/repos/$_HELIUM_REPO/releases/latest" |
    sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1
}

# installed and current; offline counts as current (nothing to compare with)
is_installed() {
  [[ -x $_HELIUM_DIR/helium-wrapper && -f $_HELIUM_DIR/.version ]] || return 1
  local latest
  latest=$(_helium_latest) && [[ -n $latest ]] || return 0
  [[ $(<"$_HELIUM_DIR/.version") == "$latest" ]]
}

# _helium_verify <file>: its .asc must be signed by Helium's key
_helium_verify() {
  if ! has gpg; then
    warn "gpg not available — skipping the signature check"
    return 0
  fi
  local gnupg="$DOT_RUN_DIR/helium-gnupg"
  mkdir -p "$gnupg" && chmod 700 "$gnupg"
  if ! gpg --homedir "$gnupg" -q --keyserver hkps://keys.openpgp.org --recv-keys "$_HELIUM_KEY" 2>/dev/null; then
    warn "couldn't fetch Helium's signing key — skipping the signature check"
    return 0
  fi
  gpg --homedir "$gnupg" -q --verify "$1.asc" "$1" 2>/dev/null ||
    { err "signature check FAILED for $(basename "$1") — not installing"; return 1; }
  ok "signature verified (Helium signing key)"
}

setup() {
  local tag arch name url tmp="$DOT_RUN_DIR/helium"
  tag=$(_helium_latest)
  [[ -n $tag ]] || { err "can't reach GitHub to find the latest Helium release"; return 1; }
  arch=$(goarch) # x86_64 | arm64, as in the release names
  name="helium-$tag-${arch}_linux"
  url="https://github.com/$_HELIUM_REPO/releases/download/$tag/$name.tar.xz"

  local progress=-sS
  [[ -t 2 ]] && progress=--progress-bar
  info "Helium $tag ($arch)"
  run mkdir -p "$tmp"
  run curl -fL "$progress" -o "$tmp/$name.tar.xz" "$url"
  run curl -fsSL -o "$tmp/$name.tar.xz.asc" "$url.asc"
  _helium_verify "$tmp/$name.tar.xz"
  run tar -xJf "$tmp/$name.tar.xz" -C "$tmp"
  echo "$tag" >"$tmp/$name/.version"

  # swap in the new release in one step
  run mkdir -p "$(dirname "$_HELIUM_DIR")" "$HOME/.local/bin"
  run rm -rf "$_HELIUM_DIR.new"
  run mv "$tmp/$name" "$_HELIUM_DIR.new"
  run rm -rf "$_HELIUM_DIR"
  run mv "$_HELIUM_DIR.new" "$_HELIUM_DIR"
  run ln -sfn "$_HELIUM_DIR/helium-wrapper" "$HOME/.local/bin/helium"

  # launcher entry and icon
  run mkdir -p "$(dirname "$_HELIUM_APP")" "$(dirname "$_HELIUM_ICON")"
  sed "s|^Exec=helium|Exec=$_HELIUM_DIR/helium-wrapper|" "$_HELIUM_DIR/helium.desktop" >"$_HELIUM_APP"
  run cp "$_HELIUM_DIR/product_logo_256.png" "$_HELIUM_ICON"
  has update-desktop-database && update-desktop-database "$(dirname "$_HELIUM_APP")" 2>/dev/null
  ok "installed Helium $tag → ~/.local/bin/helium"
}

# xdg-settings reads/writes ~/.config/mimeapps.list — the same call `omarchy
# default browser` makes (it just doesn't list Helium)
_helium_xdg() { env -u BROWSER XDG_CURRENT_DESKTOP= xdg-settings "$@"; }

configure() {
  [[ $HELIUM_DEFAULT_BROWSER == 1 && -f $_HELIUM_APP ]] && has xdg-settings || return 0
  [[ $(_helium_xdg get default-web-browser 2>/dev/null) == helium.desktop ]] && return 0
  run _helium_xdg set default-web-browser helium.desktop
  ok "Helium is the default browser"
}

teardown() {
  if has xdg-settings && [[ $(_helium_xdg get default-web-browser 2>/dev/null) == helium.desktop ]]; then
    warn "Helium was the default browser — pick another, e.g.: omarchy default browser chromium"
  fi
  run rm -rf "$_HELIUM_DIR" "$HOME/.local/bin/helium" "$_HELIUM_APP" "$_HELIUM_ICON"
}
