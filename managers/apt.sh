# shellcheck shell=bash
# Debian / Ubuntu packages. Module variable: APT=(...) — also receives PKGS on Debian family.
M_DESC="Debian/Ubuntu packages (apt)"
M_VAR=APT
M_FAMILY=debian

m_available() { [[ $OS_FAMILY == debian ]] && has apt-get; }
m_ensure() { :; }
m_has() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'; }
m_install() {
  if [[ ! -e $DOT_RUN_DIR/apt-updated ]]; then
    touch "$DOT_RUN_DIR/apt-updated"
    as_root apt-get update || return 1
  fi
  as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}
m_remove() { as_root env DEBIAN_FRONTEND=noninteractive apt-get remove -y "$@"; }
