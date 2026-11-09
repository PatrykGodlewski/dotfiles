# shellcheck shell=bash
# `dot sync`: find what changed on this machine that the repo doesn't know yet.
# Every collector prints changes as "type<TAB>payload<TAB>label":
#   profile    <omarchy command>   record/replace this line in the profile
#   config     <~/path>            a config dot copied here was edited -> update repo
#   conflict   <~/path>            ... and the repo changed too (opt-in)
#   newconfig  <~/path>            an untracked config -> capture into a module
# Nothing here modifies anything; cmd/sync.sh shows, picks and applies.

SYNC_IGNORE="$DOT_ROOT/sync.ignore"
SYNC_MAX_NEW_KB=${SYNC_MAX_NEW_KB:-2048} # bigger untracked dirs are app data, not config

# sync_ignored <kind> <name>: matches a "<kind> <glob>" line in sync.ignore
sync_ignored() {
  [[ -f $SYNC_IGNORE ]] || return 1
  local kind pat
  while read -r kind pat; do
    [[ $kind == "$1" && -n $pat ]] || continue
    # shellcheck disable=SC2053
    [[ $2 == $pat ]] && return 0
  done < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$SYNC_IGNORE")
  return 1
}

_change() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

# ---------------------------------------------------------------- omarchy
sync_omarchy_changes() {
  om_available || return 0
  local cmd key found n old
  # defaults / theme / font that differ from (or are missing in) the profile
  while read -r cmd; do
    key=$(profile_key "$cmd")
    if found=$(profile_find "$key"); then
      IFS=$'\t' read -r n old <<<"$found"
      local -a w; mapfile -t w < <(profile_split "$old")
      [[ $(om_check "${w[@]}") == pending ]] && _change profile "$cmd" "$old  →  $cmd"
    else
      _change profile "$cmd" "record: $cmd"
    fi
  done < <(om_state)
  _sync_package_changes
  _sync_app_changes
}

# words of every profile line starting with the given words, e.g. "pkg add"
_profile_args_of() {
  local n cmd prefix=$*
  while IFS=$'\t' read -r n cmd; do
    [[ $cmd == "$prefix "* ]] && profile_split "${cmd#"$prefix "}"
  done < <(profile_entries)
}

# packages every module declares, for any manager
_declared_pkgs() {
  local n m
  for n in $(mod_all); do
    mod_load "$n"
    for m in "${MGR_ORDER[@]}"; do mod_pkgs "$m"; done
  done
}

_sync_package_changes() {
  local p
  local -A base=() known=() installed=() foreign=()
  while read -r p; do [[ -n $p ]] && base[$p]=1; done < <(om_pkg_defaults)
  while read -r p; do [[ -n $p ]] && known[$p]=1; done < <(
    _declared_pkgs; _profile_args_of pkg add; _profile_args_of pkg aur add; _profile_args_of pkg drop)
  while read -r p; do installed[$p]=1; done < <(pacman -Qq 2>/dev/null)
  while read -r p; do foreign[$p]=1; done < <(pacman -Qqm 2>/dev/null)

  # installed by you (explicitly), not by Omarchy
  while read -r p; do
    [[ -z $p || -n ${base[$p]:-} || -n ${known[$p]:-} ]] && continue
    sync_ignored pkg "$p" && continue
    if [[ -n ${foreign[$p]:-} ]]; then
      _change profile "pkg aur add $p" "installed: $p (AUR)"
    else
      _change profile "pkg add $p" "installed: $p"
    fi
  done < <(pacman -Qqe 2>/dev/null)

  # Omarchy defaults you removed
  while read -r p; do
    [[ -z $p || -n ${installed[$p]:-} || -n ${known[$p]:-} ]] && continue
    sync_ignored pkg "$p" && continue
    _change profile "pkg drop $p" "removed: $p (an Omarchy default)"
  done < <(has omarchy-pkg-defaults && omarchy-pkg-defaults 2>/dev/null)
}

_sync_app_changes() {
  local kind name cmd
  local -A have=()
  while IFS=$'\t' read -r kind name; do have[$name]=1; done < <(om_apps_installed)
  while IFS=$'\t' read -r kind name; do
    [[ -n ${have[$name]:-} ]] && continue
    sync_ignored app "$name" && continue
    cmd=$(profile_join "$kind" remove "$name")
    profile_find "$(profile_key "$cmd")" >/dev/null && continue
    _change profile "$cmd" "removed preinstalled $kind: $name"
  done < <(om_apps_preinstalled)
}

# ---------------------------------------------------------------- configs
sync_config_changes() {
  local mod dst hash
  # copies dot installed that were edited here since
  while IFS=$'\t' read -r mod dst hash; do
    [[ -e $dst && ! -L $dst ]] || continue
    case $(copy_status "$mod" "$dst" "$hash") in
      local) _change config "$(pretty "$dst")" "changed here: $(pretty "$dst")  (module $mod)" ;;
      both) _change conflict "$(pretty "$dst")" "changed here AND in the repo: $(pretty "$dst") — check the diff" ;;
    esac
  done < <(copy_rec_list)
  _sync_new_configs
}

# untracked entries in ~/.config: Omarchy configs you customized, and configs
# of apps you added (small dirs only: big ones are caches / browser profiles)
_sync_new_configs() {
  local -A managed=() omdef=()
  local n src dst e name kb
  for n in $(mod_all); do
    while IFS=$'\t' read -r src dst; do managed[$dst]=1; done < <(links_of "$n")
  done
  while read -r name; do omdef[$name]=1; done < <(om_config_defaults)
  for e in "$HOME"/.config/* "$HOME"/.config/.[!.]*; do
    [[ -e $e && ! -L $e && -z ${managed[$e]:-} ]] || continue
    name=${e##*/}
    [[ $name == dotfiles ]] && continue
    sync_ignored config "$name" && continue
    kb=$(du -sk "$e" 2>/dev/null | cut -f1)
    ((kb <= SYNC_MAX_NEW_KB)) || continue
    if [[ -n ${omdef[$name]:-} ]]; then
      diff -rq "$OM_SHARE/config/$name" "$e" >/dev/null 2>&1 && continue
      _change newconfig "$(pretty "$e")" "customized Omarchy config: $(pretty "$e")"
    else
      _change newconfig "$(pretty "$e")" "untracked config: $(pretty "$e") (${kb}K)"
    fi
  done
}

# module a new config gets captured into: Omarchy configs -> omarchy, else its own
sync_target_module() {
  local name=${1##*/}
  if [[ -e $OM_SHARE/config/$name ]]; then echo omarchy; return; fi
  name=${name#.}
  name=${name%%.*}
  printf '%s\n' "${name//[^a-zA-Z0-9_-]/-}"
}

# sync_ignore_line <type> <payload> -> the sync.ignore line that silences it ("" if none)
sync_ignore_line() {
  local -a w
  case $1 in
    newconfig) printf 'config %s\n' "${2##*/}" ;;
    profile)
      mapfile -t w < <(profile_split "$2")
      case ${w[0]}:${w[1]:-} in
        pkg:add | pkg:drop) printf 'pkg %s\n' "${w[2]}" ;;
        pkg:aur) printf 'pkg %s\n' "${w[3]}" ;;
        webapp:remove | tui:remove) printf 'app %s\n' "${w[*]:2}" ;;
      esac ;;
  esac
}

# sync_ignore_add <line>...: append to sync.ignore (skipping ones already there)
sync_ignore_add() {
  local l
  for l in "$@"; do
    grep -qxF "$l" "$SYNC_IGNORE" 2>/dev/null && continue
    [[ $DOT_DRY == 1 ]] || printf '%s\n' "$l" >>"$SYNC_IGNORE"
    ok "ignoring from now on: $l"
  done
}
