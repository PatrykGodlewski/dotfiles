# shellcheck shell=bash
# Rust crates via `cargo install` (rustup bootstrapped if missing). Module variable: CARGO=(...)
M_DESC="Rust crates (cargo install)"
M_VAR=CARGO

_cargo_path() { [[ -d $HOME/.cargo/bin ]] && export PATH="$HOME/.cargo/bin:$PATH"; return 0; }
m_available() { true; }
m_ensure() {
  _cargo_path
  has cargo && return 0
  info "Installing Rust toolchain (rustup)"
  case $OS_FAMILY in
    arch) native_install rustup && run rustup default stable ;;
    *) run_sh 'curl --proto =https --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path' ;;
  esac
  _cargo_path
}
m_has() { _cargo_path; has cargo && cargo install --list 2>/dev/null | grep -q "^$1 v"; }
m_install() { _cargo_path; run cargo install --locked "$@"; }
m_remove() { _cargo_path; run cargo uninstall "$@"; }
