# shellcheck shell=bash
# Thin adapters over Omarchy's own commands and data. Omarchy does all the
# real work (installing, setting defaults, removing apps); dot only reads:
#   omarchy default <kind>, theme current, font current   current choices
#   omarchy commands --json                                catalog for "add"
#   omarchy-pkg-defaults, $OMARCHY_PATH/applications       what Omarchy preinstalls
#   omarchy pkg present                                    package checks

OM_DEFAULT_KINDS=(browser terminal editor agent)
OM_SHARE=${OMARCHY_PATH:-/usr/share/omarchy}

# DOT_OMARCHY=0 turns the integration off (e.g. to manage a non-Omarchy setup)
om_available() { [[ ${DOT_OMARCHY:-1} != 0 ]] && has omarchy; }
om_require() { om_available || die "not an Omarchy system (no 'omarchy' command)"; }

# The editor getter prints a binary name; the setter takes an option name.
_om_editor_option() { case $1 in zeditor) echo zed ;; subl) echo sublime_text ;; *) echo "$1" ;; esac; }
_om_norm() { tr '[:upper:] ' '[:lower:]-' <<<"$*"; }

# om_default <kind> -> current value, spelled the way `omarchy default <kind>` takes it
om_default() {
  local v
  v=$(omarchy default "$1" 2>/dev/null) || return 1
  [[ $1 == editor ]] && v=$(_om_editor_option "$v")
  printf '%s' "$v"
}

# om_state -> the machine's current defaults / theme / font as profile commands
om_state() {
  local k v
  for k in "${OM_DEFAULT_KINDS[@]}"; do
    v=$(om_default "$k") && [[ -n $v ]] && profile_join default "$k" "$v"
  done
  v=$(omarchy theme current 2>/dev/null) && [[ -n $v ]] && profile_join theme set "$v"
  v=$(omarchy font current 2>/dev/null) && [[ -n $v ]] && profile_join font set "$v"
  return 0
}

# om_check <word>... -> done | pending | unknown  (is this command in effect?)
om_check() {
  case ${1:-}:${2:-} in
    default:browser | default:terminal | default:editor | default:agent)
      [[ $(om_default "$2") == "$(_om_editor_option "${3:-}")" ]] && echo done || echo pending ;;
    theme:set)
      [[ $(_om_norm "$(omarchy theme current 2>/dev/null)") == "$(_om_norm "${@:3}")" ]] && echo done || echo pending ;;
    font:set)
      [[ $(omarchy font current 2>/dev/null) == "${*:3}" ]] && echo done || echo pending ;;
    webapp:remove | tui:remove)
      [[ -e $HOME/.local/share/applications/${*:3}.desktop ]] && echo pending || echo done ;;
    pkg:add) omarchy pkg present "${@:3}" >/dev/null 2>&1 && echo done || echo pending ;;
    pkg:aur) [[ ${3:-} == add ]] || { echo unknown; return; }
      omarchy pkg present "${@:4}" >/dev/null 2>&1 && echo done || echo pending ;;
    pkg:drop)
      local p
      for p in "${@:3}"; do omarchy pkg present "$p" >/dev/null 2>&1 && { echo pending; return; }; done
      echo done ;;
    *) echo unknown ;;
  esac
}

# om_apps <dir> -> "webapp<TAB>Name" / "tui<TAB>Name" for the .desktop files in
# dir, classified with the same Exec patterns `omarchy webapp/tui remove` use
om_apps() {
  local f
  for f in "$1"/*.desktop; do
    [[ -f $f ]] || continue
    if grep -q '^Exec=.*\(omarchy-launch-webapp\|omarchy-webapp-handler\)' "$f"; then
      printf 'webapp\t%s\n' "$(basename "$f" .desktop)"
    elif grep -qE '^Exec=.*(\$TERMINAL|xdg-terminal-exec).*-e' "$f"; then
      printf 'tui\t%s\n' "$(basename "$f" .desktop)"
    fi
  done
}
om_apps_installed() { om_apps "$HOME/.local/share/applications"; }
om_apps_preinstalled() { om_apps "$OM_SHARE/applications"; }

# Packages Omarchy installs itself (its default lists + extras it pulls in)
om_pkg_defaults() {
  has omarchy-pkg-defaults && omarchy-pkg-defaults 2>/dev/null
  [[ -f $OM_SHARE/install/omarchy-other.packages ]] &&
    sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$OM_SHARE/install/omarchy-other.packages"
  return 0
}

# Config entries Omarchy ships defaults for (names under ~/.config)
om_config_defaults() { [[ -d $OM_SHARE/config ]] && ls -A "$OM_SHARE/config"; return 0; }

# om_catalog -> "command<TAB>summary" for every `omarchy default|install|remove`
# command that needs no free-form input; choice lists like <a|b> are expanded.
om_catalog() {
  has jq || die "jq is needed to read the omarchy command catalog"
  local route args summary g
  local -a groups
  # \x1f separator: with a tab, read would merge an empty args field away
  while IFS=$'\x1f' read -r route args summary; do
    groups=()
    for g in $args; do [[ $g == [\[\<]--* ]] || groups+=("$g"); done # drop flags
    if ((${#groups[@]} == 0)); then
      printf '%s\t%s\n' "$route" "$summary"
    elif ((${#groups[@]} == 1)) && [[ ${groups[0]} == *'|'* ]]; then
      g=${groups[0]:1:-1}
      local c
      for c in ${g//|/ }; do printf '%s %s\t%s\n' "$route" "$c" "$summary"; done
    fi
  done < <(omarchy commands --json 2>/dev/null | jq -r '
    .commands[] | select(.hidden | not)
    | select(.route | test("^omarchy (default|install|remove) "))
    | select(.route != "omarchy install preinstalls" and .route != "omarchy remove preinstalls")
    | [(.route | sub("^omarchy "; "")), (.args // ""), .summary] | join("\u001f")')
}
