# shellcheck shell=bash disable=SC2034
# Pending-upgrade notification + bar widget (Omarchy, pacman, AUR, mise).
#   ~/.local/bin/upgrade-check            the checker (run `upgrade-check help`)
#   ~/.local/share/upgrade-check/plugin   bar widget, linked as local.upgrades
#   ~/.local/share/upgrade-check/hooks    post-boot (toast) / post-update (clear)
#   ~/.local/share/upgrade-check/checkers one script per source; add more there or in
#                                         ~/.config/upgrade-check/checkers (see README.md)
# The widget replaces Omarchy's own omarchy.system-update icon in the bar, since
# it covers Omarchy updates too. teardown() puts the stock icon back.
DESC="Startup toast + bar widget for pending upgrades (Omarchy, pacman, AUR, mise)"
ONLY_ON=(omarchy)
PACMAN=(jq pacman-contrib)

_UPG_SHARE="$HOME/.local/share/upgrade-check"
_UPG_PLUGIN="$HOME/.config/omarchy/plugins/local.upgrades"
_UPG_HOOKS="$HOME/.config/omarchy/hooks"

_upg_link() { # _upg_link <src> <dst>
  [[ -L $2 && $(readlink "$2") == "$1" ]] && return 0
  [[ -e $2 && ! -L $2 ]] && { warn "$(pretty "$2") exists and is not a link; leaving it"; return 0; }
  run mkdir -p "$(dirname "$2")"
  run ln -sfn "$1" "$2"
}

_upg_in_bar() { jq -e --arg id "$1" '[.bar.layout[]?[]?.id] | index($id)' ~/.config/omarchy/shell.json &>/dev/null; }

configure() {
  _upg_link "$_UPG_SHARE/plugin" "$_UPG_PLUGIN"
  _upg_link "$_UPG_SHARE/hooks/post-boot" "$_UPG_HOOKS/post-boot.d/upgrade-check"
  _upg_link "$_UPG_SHARE/hooks/post-update" "$_UPG_HOOKS/post-update.d/upgrade-check"

  if ! _upg_in_bar local.upgrades; then
    run omarchy-shell -q shell rescanPlugins
    local _i # the rescan is async; wait until the shell knows the plugin
    for _i in {1..20}; do
      omarchy plugin list 2>/dev/null | grep -q '^local\.upgrades ' && break
      sleep 0.5
    done
    if _upg_in_bar omarchy.system-update; then
      run omarchy plugin enable local.upgrades --after omarchy.system-update
    else
      run omarchy plugin enable local.upgrades --section centerEnd
    fi
  fi
  _upg_in_bar omarchy.system-update && run omarchy plugin disable omarchy.system-update
  return 0
}

teardown() {
  _upg_in_bar local.upgrades && run omarchy plugin disable local.upgrades
  _upg_in_bar omarchy.system-update || run omarchy plugin enable omarchy.system-update --section centerEnd
  local l
  for l in "$_UPG_PLUGIN" "$_UPG_HOOKS/post-boot.d/upgrade-check" "$_UPG_HOOKS/post-update.d/upgrade-check"; do
    [[ -L $l ]] && run rm -f "$l"
  done
  return 0
}
