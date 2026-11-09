# shellcheck shell=bash
# dot omarchy — manage modules/omarchy/profile, a list of plain omarchy commands.
#   (none)          interactive menu (status when not on a terminal)
#   status          which profile lines are in effect
#   apply [--all]   pick lines to run (nothing preselected); --yes runs pending ones
#   add [cmd...]    add lines — picked from omarchy's own catalog — without running them
#   remove [n...]   delete lines (does not undo them on the system)
#   sync            record what changed on this machine (same as: dot sync --omarchy)
#   edit            open the profile in $EDITOR

cmd_omarchy() {
  local sub=${1:-}
  (($#)) && shift
  case $sub in
    '') if ui_interactive && [[ $DOT_YES != 1 ]]; then omarchy_menu; else omarchy_status; fi ;;
    status | st) omarchy_status ;;
    apply) omarchy_apply "$@" ;;
    add) omarchy_add "$@" ;;
    remove | rm) omarchy_remove "$@" ;;
    sync) cmd_sync --omarchy ;;
    edit) "${EDITOR:-vi}" "$PROFILE_FILE" ;;
    *) die "usage: dot omarchy [status|apply [--all]|add [command]|remove [line]|sync|edit]" ;;
  esac
}

omarchy_menu() {
  om_require
  local choice
  while true; do
    choice=$(ui_choose_one "Omarchy profile — $(pretty "$PROFILE_FILE")" \
      "$(ui_sep "Profile")" \
      "status"$'\t'"what is in effect" \
      "add"$'\t'"add defaults, theme, installers, removals (nothing runs)" \
      "remove"$'\t'"delete lines from the profile" \
      "edit"$'\t'"open the profile in \$EDITOR" \
      "$(ui_sep "Machine")" \
      "apply"$'\t'"run chosen profile lines (installs / sets / removes)" \
      "sync"$'\t'"record changes made here (e.g. via the Omarchy menu)" \
      "$(ui_sep "")" \
      "back"$'\t'"") || return 0
    [[ $choice == back ]] && return 0
    cmd_omarchy "$choice"
    printf '\n'
  done
}

# Review the profile once. Fills OM_IDS / OM_CMDS / OM_STATES (parallel arrays,
# lines not yet in effect only) and prints a summary.
omarchy_review() {
  OM_IDS=() OM_CMDS=() OM_STATES=()
  local n cmd st key
  local -a w
  local -A seen=()
  header "omarchy profile"
  while IFS=$'\t' read -r n cmd; do
    key=$(profile_key "$cmd")
    [[ -n ${seen[$key]:-} ]] && warn "line $n repeats '$key' from line ${seen[$key]} — the later one wins when applied"
    seen[$key]=$n
    mapfile -t w < <(profile_split "$cmd")
    st=$(om_check "${w[@]}")
    case $st in
      done) printf '  %s omarchy %s\n' "$(_sym =)" "$cmd"; continue ;;
      pending) printf '  %s omarchy %s\n' "$(_sym +)" "$cmd" ;;
      *) printf '  %s omarchy %s %s(not checkable)%s\n' "$(_sym '~')" "$cmd" "$C_DIM" "$C_RESET" ;;
    esac
    OM_IDS+=("$n") OM_CMDS+=("$cmd") OM_STATES+=("$st")
  done < <(profile_entries)
  printf '\n%s%s in effect  %s not yet  %s not checkable (run it to be sure)%s\n' \
    "$C_DIM" "$(_sym =)" "$(_sym +)" "$(_sym '~')" "$C_RESET"
}

omarchy_status() {
  om_require
  omarchy_review
  ((${#OM_IDS[@]})) || ok "Everything in the profile is in effect."
}

omarchy_apply() {
  local all=0 a
  for a in "$@"; do
    case $a in --all) all=1 ;; *) die "usage: dot omarchy apply [--all]" ;; esac
  done
  om_require
  omarchy_review
  ((${#OM_IDS[@]})) || { ok "Everything in the profile is in effect."; return 0; }

  local i
  local -a items=() chosen=()
  for i in "${!OM_IDS[@]}"; do
    items+=("$i"$'\t'"omarchy ${OM_CMDS[i]}  · ${OM_STATES[i]}")
  done
  if ui_interactive && [[ $DOT_YES != 1 ]]; then
    UI_NAME_W=3 ui_pick_many chosen "Run which? (nothing is preselected; space = toggle, enter = confirm)" "" "${items[@]}" ||
      { info "Cancelled."; return 1; }
  elif [[ $DOT_YES == 1 ]]; then
    for i in "${!OM_IDS[@]}"; do
      [[ ${OM_STATES[i]} == pending || ($all == 1 && ${OM_STATES[i]} == unknown) ]] && chosen+=("$i")
    done
  else
    die "not a terminal: pass --yes to run the pending lines (--all: also the uncheckable ones)"
  fi
  ((${#chosen[@]})) || { info "Nothing chosen."; return 0; }

  printf '\nWill run:\n'
  for i in "${chosen[@]}"; do printf '  omarchy %s\n' "${OM_CMDS[i]}"; done
  [[ $DOT_DRY == 1 ]] || ui_confirm "Run ${#chosen[@]} command(s)?" || { info "Cancelled."; return 1; }

  local failed=0
  local -a w
  for i in "${chosen[@]}"; do
    mapfile -t w < <(profile_split "${OM_CMDS[i]}")
    run omarchy "${w[@]}" || { err "failed: omarchy ${OM_CMDS[i]}"; failed=$((failed + 1)); }
  done
  ((failed == 0))
}

# ---------------------------------------------------------------- add
omarchy_add() {
  local -a cmds=()
  if (($#)); then
    [[ $1 == omarchy ]] && shift
    cmds=("$(profile_join "$@")")
  else
    ui_interactive || die "usage: dot omarchy add <omarchy command>   e.g. dot omarchy add install dev-env node"
    om_require
    _omarchy_pick_additions cmds || { info "Cancelled."; return 1; }
  fi
  ((${#cmds[@]})) || { info "Nothing added."; return 0; }
  local new="$DOT_RUN_DIR/profile.new"
  profile_with_set "$PROFILE_FILE" "${cmds[@]}" >"$new"
  profile_write "$PROFILE_FILE" "$new" || return 0
  info "nothing was run — apply it when you want: dot omarchy apply"
}

# _omarchy_pick_additions <array-var>: interactive catalog browser
_omarchy_pick_additions() {
  local -n _out=$1
  local kind
  kind=$(ui_choose_one "Add what to the profile?" \
    "default"$'\t'"default browser / terminal / editor / agent" \
    "theme"$'\t'"theme" \
    "font"$'\t'"monospace font" \
    "install"$'\t'"software via omarchy's installers" \
    "uninstall"$'\t'"software via omarchy's removers" \
    "drop-app"$'\t'"remove preinstalled web apps / TUIs" \
    "drop-pkg"$'\t'"remove preinstalled packages" \
    "pkg"$'\t'"install extra packages (pacman / AUR)") || return 1

  local -a items=() picked=()
  local line cmd sum k name
  case $kind in
    default | install | uninstall)
      local prefix=$kind; [[ $kind == uninstall ]] && prefix=remove
      local i=0
      local -A cmd_of=()
      while IFS=$'\t' read -r cmd sum; do
        [[ $cmd == "$prefix "* ]] || continue
        i=$((i + 1)); cmd_of[$i]=$cmd
        items+=("$i"$'\t'"$cmd  ${C_DIM}— $sum${C_RESET}")
      done < <(om_catalog)
      UI_NAME_W=4 ui_pick_many picked "Pick (space = toggle, enter = confirm)" "" "${items[@]}" || return 1
      for k in "${picked[@]}"; do _out+=("${cmd_of[$k]}"); done
      ;;
    theme | font)
      local -a names
      mapfile -t names < <(omarchy "$kind" list 2>/dev/null)
      local pick
      pick=$(_pick_by_number "Which $kind?" "${names[@]}") || return 1
      _out+=("$(profile_join "$kind" set "$pick")")
      ;;
    drop-app)
      local i=0
      local -A cmd_of=()
      while IFS=$'\t' read -r k name; do
        i=$((i + 1)); cmd_of[$i]=$(profile_join "$k" remove "$name")
        items+=("$i"$'\t'"$k  $name")
      done < <(om_apps_installed)
      ((i)) || { info "No web apps / TUIs installed."; return 0; }
      UI_NAME_W=4 ui_pick_many picked "Remove which?" "" "${items[@]}" || return 1
      for k in "${picked[@]}"; do _out+=("${cmd_of[$k]}"); done
      ;;
    drop-pkg)
      local -a pk=()
      while read -r name; do
        omarchy pkg present "$name" >/dev/null 2>&1 && pk+=("$name"$'\t')
      done < <(has omarchy-pkg-defaults && omarchy-pkg-defaults)
      ui_pick_many picked "Remove which preinstalled packages?" "" "${pk[@]}" || return 1
      ((${#picked[@]})) && _out+=("$(profile_join pkg drop "${picked[@]}")")
      ;;
    pkg)
      line=$(ui_input "Packages (space separated)")
      [[ -n $line ]] || return 0
      local aur
      aur=$(ui_choose_one "From where?" "repo"$'\t'"official repos (omarchy pkg add)" "aur"$'\t'"AUR (omarchy pkg aur add)") || return 1
      local -a words; read -ra words <<<"$line"
      if [[ $aur == aur ]]; then _out+=("$(profile_join pkg aur add "${words[@]}")"); else _out+=("$(profile_join pkg add "${words[@]}")"); fi
      ;;
  esac
}

# _pick_by_number "Header" value... -> one value (works for values with spaces)
_pick_by_number() {
  local h=$1 i k; shift
  local -a items=() vals=("$@")
  for i in "${!vals[@]}"; do items+=("$((i + 1))"$'\t'"${vals[i]}"); done
  k=$(UI_NAME_W=4 ui_choose_one "$h" "${items[@]}") || return 1
  printf '%s\n' "${vals[k - 1]}"
}

# ---------------------------------------------------------------- remove
omarchy_remove() {
  local -a drop=() items=()
  local n cmd
  if (($#)); then
    for n in "$@"; do [[ $n =~ ^[0-9]+$ ]] || die "usage: dot omarchy remove <line number>... (see: dot omarchy status)"; done
    drop=("$@")
  else
    ui_interactive || die "usage: dot omarchy remove <line number>..."
    while IFS=$'\t' read -r n cmd; do items+=("$n"$'\t'"$cmd"); done < <(profile_entries)
    ((${#items[@]})) || { info "The profile is empty."; return 0; }
    UI_NAME_W=4 ui_pick_many drop "Delete which lines? (only from the profile — nothing is undone)" "" "${items[@]}" ||
      { info "Cancelled."; return 1; }
  fi
  ((${#drop[@]})) || { info "Nothing chosen."; return 0; }
  local new="$DOT_RUN_DIR/profile.new"
  profile_without "$PROFILE_FILE" "${drop[@]}" >"$new"
  profile_write "$PROFILE_FILE" "$new" || return 0
  info "to undo something on the system, add its opposite (e.g. 'remove dev env node') and apply"
}
