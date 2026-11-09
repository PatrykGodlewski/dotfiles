# shellcheck shell=bash
# Module commands: status, list, plan, apply, select, preset, remove, prune.

mod_items() { # "name<TAB>desc" for supported, non-required modules
  local n why
  for n in $(mod_all); do
    mod_load "$n"
    [[ $REQUIRED == 1 ]] && continue
    why=$(mod_supported) || continue
    printf '%s\t%s\n' "$n" "$DESC"
  done
}

targets_or_selection() { # prints targets; falls back to saved selection
  if (($#)); then printf '%s\n' "$@"; else sel_get; fi
}

show_plan() { # show_plan module... ; sets TOTAL_CHANGES
  TOTAL_CHANGES=0
  local n
  for n in "$@"; do
    mod_plan "$n"
    TOTAL_CHANGES=$((TOTAL_CHANGES + PLAN_CHANGES))
  done
  printf '\n%sLegend:%s %s install/link  %s already done  %s backup existing  %s skipped\n' \
    "$C_DIM" "$C_RESET" "$(_sym +)" "$(_sym '=')" "$(_sym '!')" "$(_sym '~')"
}

run_apply() { # run_apply module... (already resolved)
  local n rc
  local -a good=() bad=() skipped=()
  for n in "$@"; do
    mod_apply "$n"; rc=$?
    case $rc in
      0) good+=("$n") ;;
      3) skipped+=("$n") ;;
      *) bad+=("$n") ;;
    esac
  done
  header "Summary"
  ((${#good[@]})) && ok "done:    ${good[*]}"
  ((${#skipped[@]})) && info "skipped: ${skipped[*]}"
  ((${#bad[@]})) && err "failed:  ${bad[*]}"
  [[ -d $BACKUP_DIR ]] && info "backups: $(pretty "$BACKUP_DIR")"
  ((${#bad[@]} == 0))
}

cmd_status() {
  header "dot status — $(os_summary)"
  printf '%s%-14s %-4s %-9s %-7s %-9s %s%s\n' "$C_BOLD" MODULE SEL PACKAGES SETUP LINKS STATE "$C_RESET"
  local n s sel pk setup links state color
  for n in $(mod_all); do
    s=$(mod_status "$n")
    if sel_has "$n"; then sel="${C_GREEN}●${C_RESET}"; else sel="${C_DIM}○${C_RESET}"; fi
    if [[ $s == unsupported* ]]; then
      printf '%s%-14s%s %b    %s%s%s\n' "$C_DIM" "$n" "$C_RESET" "$sel" "$C_DIM" "${s#*|}" "$C_RESET"
      continue
    fi
    IFS='|' read -r _ pko pkt setup lo lt lb <<<"$s"
    pk="$pko/$pkt"; ((pkt == 0)) && pk='-'
    links="$lo/$lt"; ((lt == 0)) && links='-'
    ((lb > 0)) && links+='!'
    if [[ $pko == "$pkt" && $setup != no && $lo == "$lt" ]]; then
      state=ready color=$C_GREEN
    elif ((pko == 0 && lo == 0)) && [[ $setup != yes ]]; then
      state=missing color=$C_DIM
    else
      state=partial color=$C_YELLOW
    fi
    case $setup in # multibyte symbols: pad by hand
      yes) setup="${C_GREEN}✓${C_RESET}      " ;;
      no) setup="${C_RED}✗${C_RESET}      " ;;
      *) setup=$(printf '%-7s' "$setup") ;;
    esac
    printf '%-14s %b    %-9s %s %-9s %s%s%s\n' "$n" "$sel" "$pk" "$setup" "$links" "$color" "$state" "$C_RESET"
  done
  printf '\n%s● selected on this machine   links "!" = conflicting file   run "dot plan" for details%s\n' "$C_DIM" "$C_RESET"
}

cmd_list() {
  header "Modules"
  local n why
  for n in $(mod_all); do
    mod_load "$n"
    if why=$(mod_supported); then
      printf '  %-14s %s\n' "$n" "$DESC"
    else
      printf '  %s%-14s %s  [%s]%s\n' "$C_DIM" "$n" "$DESC" "$why" "$C_RESET"
    fi
  done
  header "Presets"
  for n in $(preset_all); do
    printf '  %-14s %s\n' "@$n" "$(preset_desc "$n")"
    printf '  %-14s %s%s%s\n' '' "$C_DIM" "$(preset_modules "$n" | tr '\n' ' ')" "$C_RESET"
  done
}

cmd_plan() {
  local -a t
  mapfile -t t < <(targets_or_selection "$@")
  ((${#t[@]})) || { warn "nothing selected yet — try: dot plan @headless   or   dot select"; return 1; }
  resolve "${t[@]}"
  header "Plan for: ${RESOLVED[*]}"
  show_plan "${RESOLVED[@]}"
  printf '%s%d change(s).%s\n' "$C_BOLD" "$TOTAL_CHANGES" "$C_RESET"
  prune_candidates_preview
}

cmd_apply() {
  local -a t
  mapfile -t t < <(targets_or_selection "$@")
  if ((${#t[@]} == 0)); then
    if ui_interactive; then cmd_select; return; fi
    die "nothing selected — pass modules / @preset, or run 'dot select'"
  fi
  resolve "${t[@]}"
  header "Plan"
  show_plan "${RESOLVED[@]}"
  if ((TOTAL_CHANGES == 0)); then
    ok "Everything is already applied."
    sel_add "${RESOLVED[@]}"
    return 0
  fi
  [[ $DOT_DRY == 1 ]] || ui_confirm "Apply $TOTAL_CHANGES change(s)?" || { info "Cancelled."; return 1; }
  run_apply "${RESOLVED[@]}"
  local rc=$?
  sel_add "${RESOLVED[@]}"
  return $rc
}

# Interactive picker; $1 = preselected names
pick_and_apply() {
  local pre=$1
  ui_interactive || die "select needs a terminal (use: dot apply <modules> --yes)"
  local -a items chosen
  mapfile -t items < <(mod_items)
  ui_pick_many chosen "Modules for this machine:" "$pre" "${items[@]}" || { info "Cancelled."; return 1; }
  local -a current added=() removed=()
  mapfile -t current < <(sel_get)
  local n
  for n in "${chosen[@]}"; do in_list "$n" "${current[@]}" || added+=("$n"); done
  for n in "${current[@]}"; do
    mod_load "$n"; [[ $REQUIRED == 1 ]] && continue
    in_list "$n" "${chosen[@]}" || removed+=("$n")
  done
  resolve "${chosen[@]}"
  header "Plan"
  show_plan "${RESOLVED[@]}"
  if ((${#removed[@]})); then
    printf '\n%sWill remove (unlink + deselect):%s %s\n' "$C_RED" "$C_RESET" "${removed[*]}"
  fi
  if ((TOTAL_CHANGES == 0 && ${#removed[@]} == 0)); then
    ok "Nothing to do."
    sel_write "${RESOLVED[@]}"
    return 0
  fi
  [[ $DOT_DRY == 1 ]] || ui_confirm "Proceed?" || { info "Cancelled."; return 1; }
  local rc=0
  ((${#removed[@]})) && { do_remove "${removed[@]}" || rc=1; }
  run_apply "${RESOLVED[@]}" || rc=1
  sel_write "${RESOLVED[@]}"
  return $rc
}

cmd_select() { pick_and_apply "$(sel_get | tr '\n' ' ')"; }

cmd_preset() {
  local p=${1:-}
  if [[ -z $p ]]; then
    local -a items=()
    local n
    for n in $(preset_all); do items+=("$n"$'\t'"$(preset_desc "$n")"); done
    p=$(ui_choose_one "Choose a preset (you can tweak the modules next):" "${items[@]}") || return 1
  fi
  [[ -f $DOT_ROOT/presets/$p ]] || die "unknown preset: $p (see: dot list)"
  if ! ui_interactive || [[ $DOT_YES == 1 ]]; then
    cmd_apply "@$p"
    return
  fi
  pick_and_apply "$(preset_modules "$p" | tr '\n' ' ') $(sel_get | tr '\n' ' ')"
}

do_remove() { # unlink + teardown + deselect
  local n
  local -a removed=()
  for n in "$@"; do
    mod_exists "$n" || { warn "unknown module: $n"; continue; }
    mod_load "$n"
    [[ $REQUIRED == 1 ]] && { warn "$n is required, not removing"; continue; }
    header "remove $n"
    mod_unlink "$n"
    mod_teardown "$n"
    removed+=("$n")
  done
  ((${#removed[@]})) && sel_del "${removed[@]}"
  return 0
}

cmd_remove() {
  (($#)) || {
    ui_interactive || die "usage: dot remove <module...>"
    local -a items=() picked=()
    local n
    for n in $(sel_get); do mod_load "$n"; [[ $REQUIRED == 1 ]] || items+=("$n"$'\t'"$DESC"); done
    ((${#items[@]})) || { info "Nothing selected."; return 0; }
    ui_pick_many picked "Modules to remove:" "" "${items[@]}" || { info "Cancelled."; return 1; }
    ((${#picked[@]})) || return 0
    set -- "${picked[@]}"
  }
  printf 'Will unlink configs and deselect: %s\n' "$*"
  [[ $DOT_DRY == 1 ]] || ui_confirm "Remove $*?" || return 1
  do_remove "$@"
  cmd_prune
}

# packages recorded as installed by dot that no selected module declares
prune_candidates() {
  local -A declared=()
  local n m p
  for n in $(sel_get); do
    mod_exists "$n" || continue
    mod_load "$n"
    for m in "${MGR_ORDER[@]}"; do
      while read -r p; do [[ -n $p ]] && declared["$m $p"]=1; done < <(mod_pkgs "$m")
    done
  done
  local mod
  while read -r mod m p; do
    [[ -z $p ]] && continue
    [[ -n ${declared["$m $p"]:-} ]] && continue
    printf '%s\t%s\n' "$m:$p" "(installed for $mod)"
  done < <(rec_list)
}

prune_candidates_preview() {
  local c; c=$(prune_candidates)
  [[ -z $c ]] && return 0
  printf '\n%sNo longer needed (removable with "dot prune"):%s\n' "$C_YELLOW" "$C_RESET"
  while IFS=$'\t' read -r k rest; do printf '    %s %s %s%s%s\n' "$(_sym -)" "$k" "$C_DIM" "$rest" "$C_RESET"; done <<<"$c"
}

cmd_prune() {
  local -a items chosen
  mapfile -t items < <(prune_candidates)
  ((${#items[@]})) || { ok "Nothing to prune."; return 0; }
  if ui_interactive && [[ $DOT_YES != 1 ]]; then
    ui_pick_many chosen "Uninstall these packages? (only ones dot installed)" "" "${items[@]}" || { info "Cancelled."; return 1; }
  else
    mapfile -t chosen < <(printf '%s\n' "${items[@]}" | cut -f1)
  fi
  ((${#chosen[@]})) || { info "Nothing chosen."; return 0; }
  [[ $DOT_DRY == 1 ]] || ui_confirm "Uninstall ${chosen[*]}?" || return 1
  local k m p
  for k in "${chosen[@]}"; do
    m=${k%%:*} p=${k#*:}
    if mgr "$m" m_remove "$p"; then rec_del "$m" "$p"; ok "removed $p ($m)"; else err "failed to remove $p ($m)"; fi
  done
}
