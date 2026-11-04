# shellcheck shell=bash disable=SC2034
DESC="JetBrainsMono Nerd Font (~/.local/share/fonts)"
SKIP_ON=(wsl)   # on WSL install fonts on the Windows side
PKGS=(fontconfig unzip curl)

is_installed() { fc-list 2>/dev/null | grep -qi 'JetBrainsMono Nerd'; }
setup() {
  local dir="$HOME/.local/share/fonts/JetBrainsMono"
  local url
  url=$(gh_asset_url ryanoasis/nerd-fonts '/JetBrainsMono\.zip$')
  run mkdir -p "$dir"
  run curl -fsSL -o "$DOT_RUN_DIR/jbm.zip" "$url"
  run unzip -oq "$DOT_RUN_DIR/jbm.zip" '*.ttf' -d "$dir"
  run fc-cache -f
}
