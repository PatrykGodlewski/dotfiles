# shellcheck shell=bash disable=SC2034
DESC="~/.config/dotfiles/secrets.env (API keys, sourced by zsh, never committed)"

is_installed() { [[ -f $DOT_CONFIG_DIR/secrets.env ]]; }
setup() {
  run mkdir -p "$DOT_CONFIG_DIR"
  run install -m 600 "$MOD_DIR/secrets.env.example" "$DOT_CONFIG_DIR/secrets.env"
  info "fill in $(pretty "$DOT_CONFIG_DIR/secrets.env")"
}
