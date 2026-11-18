# shellcheck shell=bash disable=SC2034
# Pending-upgrade notification + bar widget (Omarchy, pacman, AUR, mise, ...).
#   ~/.local/bin/upgrade-check             the tool; all logic (run `upgrade-check help`)
#   ~/.local/share/upgrade-check/checkers  one script per source (see its README.md);
#                                          machine-local ones: ~/.config/upgrade-check/checkers
#   ~/.local/share/upgrade-check/plugin    bar widget local.upgrades (display only)
#   ~/.local/share/upgrade-check/hooks     post-boot: check + toast · post-update: re-check
#   ~/.local/share/upgrade-check/systemd   user timer: check + toast every 3 hours
# The widget sits next to the tray and replaces Omarchy's omarchy.system-update
# icon, since it covers Omarchy updates too. teardown() restores the stock icon.
# Tests: modules/upgrades/test.sh
DESC="Startup toast + bar widget for pending upgrades (Omarchy, pacman, AUR, mise)"
ONLY_ON=(omarchy)
# jq: state/JSON · pacman-contrib: checkupdates · iputils: ping (network wait)
# util-linux: flock, setsid · coreutils: timeout, sha1sum · yay/mise-bin: AUR and
# mise checkers (they skip themselves when missing, but are wanted here)
PACMAN=(jq pacman-contrib iputils util-linux coreutils yay mise-bin)

_UPG_SHARE="$HOME/.local/share/upgrade-check"
_UPG_WIDGET=local.upgrades
_UPG_STOCK_WIDGET=omarchy.system-update
_UPG_TIMER=upgrade-check.timer
_UPG_UNIT_DIR="$HOME/.config/systemd/user"
# Links into Omarchy's config, as "source<TAB>destination". Linked individually
# because ~/.config/omarchy itself is not owned by this module.
_UPG_LINKS=(
  "$_UPG_SHARE/plugin	$HOME/.config/omarchy/plugins/$_UPG_WIDGET"
  "$_UPG_SHARE/hooks/post-boot	$HOME/.config/omarchy/hooks/post-boot.d/upgrade-check"
  "$_UPG_SHARE/hooks/post-update	$HOME/.config/omarchy/hooks/post-update.d/upgrade-check"
  "$_UPG_SHARE/systemd/upgrade-check.service	$_UPG_UNIT_DIR/upgrade-check.service"
  "$_UPG_SHARE/systemd/upgrade-check.timer	$_UPG_UNIT_DIR/upgrade-check.timer"
)

_upg_link() { # _upg_link <src> <dst>
  [[ -L $2 && $(readlink "$2") == "$1" ]] && return 0
  if [[ -e $2 && ! -L $2 ]]; then
    warn "$(pretty "$2") exists and is not a link; leaving it"
    return 0
  fi
  run mkdir -p "$(dirname "$2")"
  run ln -sfn "$1" "$2"
}

_upg_in_bar() { jq -e --arg id "$1" '[.bar.layout[]?[]?.id] | index($id)' ~/.config/omarchy/shell.json &>/dev/null; }

_upg_wait_for_widget() { # the shell's plugin rescan is asynchronous
  local _
  run omarchy-shell -q shell rescanPlugins
  for _ in {1..20}; do
    omarchy plugin list 2>/dev/null | grep -q "^${_UPG_WIDGET//./\\.} " && return 0
    sleep 0.5
  done
  warn "the shell did not pick up $_UPG_WIDGET; enable it later with: omarchy plugin enable $_UPG_WIDGET"
  return 1
}

configure() {
  local link
  for link in "${_UPG_LINKS[@]}"; do _upg_link "${link%%$'\t'*}" "${link#*$'\t'}"; done

  if ! _upg_in_bar "$_UPG_WIDGET" && _upg_wait_for_widget; then
    if _upg_in_bar omarchy.tray; then
      run omarchy plugin enable "$_UPG_WIDGET" --section right --before omarchy.tray
    else
      run omarchy plugin enable "$_UPG_WIDGET" --section right --index 0
    fi
  fi
  if _upg_in_bar "$_UPG_STOCK_WIDGET"; then run omarchy plugin disable "$_UPG_STOCK_WIDGET"; fi

  run systemctl --user daemon-reload
  systemctl --user is-enabled --quiet "$_UPG_TIMER" 2>/dev/null || run systemctl --user enable --now "$_UPG_TIMER"
  return 0
}

teardown() {
  if systemctl --user is-enabled --quiet "$_UPG_TIMER" 2>/dev/null; then run systemctl --user disable --now "$_UPG_TIMER"; fi
  if _upg_in_bar "$_UPG_WIDGET"; then run omarchy plugin disable "$_UPG_WIDGET"; fi
  _upg_in_bar "$_UPG_STOCK_WIDGET" || run omarchy plugin enable "$_UPG_STOCK_WIDGET" --section centerEnd
  local link dst
  for link in "${_UPG_LINKS[@]}"; do
    dst=${link#*$'\t'}
    if [[ -L $dst ]]; then run rm -f "$dst"; fi
  done
  run systemctl --user daemon-reload
  return 0
}
