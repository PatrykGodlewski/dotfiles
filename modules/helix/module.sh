# shellcheck shell=bash disable=SC2034
DESC="Helix editor built from source (latest master; HELIX_REBUILD=1 dot apply helix to update)"
PKGS=(git gcc)   # C compiler for tree-sitter grammars; rust comes via rustup

HELIX_SRC="$HOME/.local/src/helix"

is_installed() {
  [[ -z ${HELIX_REBUILD:-} && -x $HOME/.local/bin/hx && -d $HELIX_SRC/runtime ]]
}
setup() {
  mgr cargo m_ensure   # installs rustup + stable toolchain when missing
  export PATH="$HOME/.cargo/bin:$PATH"
  if [[ -d $HELIX_SRC/.git ]]; then
    run git -C "$HELIX_SRC" pull --ff-only
  else
    run mkdir -p "$(dirname "$HELIX_SRC")"
    run git clone https://github.com/helix-editor/helix "$HELIX_SRC"
  fi
  # builds hx + grammars (into $HELIX_SRC/runtime); binary -> ~/.local/bin/hx
  run_sh "cd '$HELIX_SRC' && cargo install --path helix-term --locked --root '$HOME/.local'"
}
configure() {
  # hx always looks in ~/.config/helix/runtime (works from any shell / launcher)
  [[ -d $HELIX_SRC/runtime ]] || return 0
  run mkdir -p "$HOME/.config/helix"
  run ln -sfnT "$HELIX_SRC/runtime" "$HOME/.config/helix/runtime"
}
teardown() {
  run rm -f "$HOME/.local/bin/hx" "$HOME/.config/helix/runtime"
  info "source kept in $(pretty "$HELIX_SRC") (delete it manually if you want)"
}
