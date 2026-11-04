# shellcheck shell=bash
# systemd units to enable (and start). Module variable: SERVICES=(...)
M_DESC="systemd services (enable --now)"
M_VAR=SERVICES

m_available() { has systemctl && [[ -d /run/systemd/system ]]; }
m_ensure() { :; }
m_has() { systemctl is-enabled --quiet "$1" 2>/dev/null; }
m_install() { as_root systemctl enable --now "$@"; }
m_remove() { as_root systemctl disable --now "$@"; }
