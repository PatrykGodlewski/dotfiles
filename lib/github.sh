# shellcheck shell=bash
# Helpers for module setup() functions: install binaries from GitHub releases
# into ~/.local (no root needed, works on every distro).

# gh_asset_url <owner/repo> <regex>  -> download URL of the latest matching asset
gh_asset_url() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" |
    grep -oE '"browser_download_url": *"[^"]+"' |
    sed -E 's/.*"(https[^"]+)"$/\1/' |
    grep -iE "$2" | head -n1
}

_gh_fetch_extract() { # url dir
  local url=$1 dir=$2 file
  file="$dir/${url##*/}"
  run mkdir -p "$dir" || return 1
  local progress=-sS
  [[ -t 2 ]] && progress=--progress-bar
  run curl -fL "$progress" -o "$file" "$url" || return 1
  case $file in
    *.tar.gz | *.tgz | *.tar.xz) run tar -xf "$file" -C "$dir" ;;
    *.zip) run unzip -oq "$file" -d "$dir" ;;
  esac
}

# gh_install_bin <owner/repo> <asset-regex> <binary-name>
# Single-binary releases (gum, lazygit, ...) -> ~/.local/bin/<binary-name>
gh_install_bin() {
  local repo=$1 re=$2 bin=$3 url dir found
  url=$(gh_asset_url "$repo" "$re") || true
  [[ -n $url ]] || { err "no release asset matching '$re' in $repo"; return 1; }
  dir="$DOT_RUN_DIR/gh-$bin"
  _gh_fetch_extract "$url" "$dir" || return 1
  [[ $DOT_DRY == 1 ]] && return 0
  found=$(find "$dir" -type f -name "$bin" | head -n1)
  [[ -n $found ]] || { err "$bin not found inside ${url##*/}"; return 1; }
  run install -Dm755 "$found" "$HOME/.local/bin/$bin"
}

# gh_install_tree <owner/repo> <asset-regex> <name>
# Releases with bin/ + lib/ (neovim) -> ~/.local/opt/<name>, bin linked into ~/.local/bin
gh_install_tree() {
  local repo=$1 re=$2 name=$3 url dir top
  url=$(gh_asset_url "$repo" "$re") || true
  [[ -n $url ]] || { err "no release asset matching '$re' in $repo"; return 1; }
  dir="$DOT_RUN_DIR/gh-$name"
  _gh_fetch_extract "$url" "$dir" || return 1
  [[ $DOT_DRY == 1 ]] && return 0
  top=$(find "$dir" -mindepth 1 -maxdepth 1 -type d | head -n1)
  run rm -rf "$HOME/.local/opt/$name" &&
    run mkdir -p "$HOME/.local/opt" "$HOME/.local/bin" &&
    run mv "$top" "$HOME/.local/opt/$name" &&
    run ln -sfn "$HOME/.local/opt/$name/bin/$name" "$HOME/.local/bin/$name"
}
