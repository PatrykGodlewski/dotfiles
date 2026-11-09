# shellcheck shell=bash
# Config commands: configs (copy/link/remove picker), link, unlink.

cmd_link() {
  local -a t; mapfile -t t < <(targets_or_selection "$@")
  local n src dst
  for n in "${t[@]}"; do
    mod_exists "$n" || { warn "unknown module: $n"; continue; }
    while IFS=$'\t' read -r src dst; do
      [[ -z $src || $(link_state "$src" "$dst") == ok ]] && continue
      link_apply "$src" "$dst" && ok "linked $(pretty "$dst")"
    done < <(links_of "$n")
  done
  [[ -d $BACKUP_DIR ]] && info "backups: $(pretty "$BACKUP_DIR")"
  return 0
}

cmd_unlink() {
  local -a t; mapfile -t t < <(targets_or_selection "$@")
  local n
  for n in "${t[@]}"; do mod_exists "$n" && mod_unlink "$n"; done
}

# dot configs [--copy|--link|--remove] [--all] [module | ~/path ...]
# Pick individual config entries and copy / link them into $HOME, or remove
# ones dot put there. Never installs packages, never changes the selection.
cmd_configs() {
  local mode='' all=0 a
  local -a want=()
  for a in "$@"; do
    case $a in
      --copy) mode=copy ;;
      --link) mode=link ;;
      --remove) mode=remove ;;
      --all) all=1 ;;
      -*) die "usage: dot configs [--copy|--link|--remove] [--all] [module|path...]" ;;
      *) want+=("${a/#\~/$HOME}") ;;
    esac
  done
  if [[ -z $mode ]]; then
    if ui_interactive && [[ $DOT_YES != 1 ]]; then
      mode=$(ui_choose_one "Configs:" \
        "copy"$'\t'"put real copies here (run again later to update them)" \
        "link"$'\t'"symlink into the repo (git pull updates them; edits land in the repo)" \
        "remove"$'\t'"remove configs dot put here (backed up first)") || { info "Cancelled."; return 1; }
    else
      mode=link
    fi
  fi

  # entries of every supported module, filtered by targets
  local -a CFG_KEYS=() CFG_SRC=() CFG_MOD=() CFG_STATE=() # read by the _cfg_* helpers
  local n src dst w hit width=14
  for n in $(mod_all); do
    mod_load "$n"
    mod_supported >/dev/null || continue
    while IFS=$'\t' read -r src dst; do
      [[ -z $src ]] && continue
      if ((${#want[@]})); then
        hit=0
        for w in "${want[@]}"; do [[ $w == "$n" || ${w%/} == "$dst" ]] && hit=1; done
        ((hit)) || continue
      fi
      CFG_KEYS+=("$(pretty "$dst")") CFG_SRC+=("$src") CFG_MOD+=("$n") CFG_STATE+=("$(link_state "$src" "$dst")")
      ((${#CFG_KEYS[-1]} + 2 > width)) && width=$((${#CFG_KEYS[-1]} + 2))
    done < <(links_of "$n")
  done
  ((${#CFG_KEYS[@]})) || die "no configs found${want:+ for: ${want[*]}}"

  # candidates for this mode
  local i done_n=0
  local -a items=() pending=()
  for i in "${!CFG_KEYS[@]}"; do
    if ! _cfg_candidate "$mode" "$i"; then
      done_n=$((done_n + 1))
      continue
    fi
    pending+=("${CFG_KEYS[i]}")
    items+=("${CFG_KEYS[i]}"$'\t'"${CFG_MOD[i]} · $(_cfg_label "$mode" "$i")")
  done
  [[ $mode != remove ]] && ((done_n)) &&
    info "$done_n config(s) already $([[ $mode == copy ]] && echo "up to date" || echo linked)"
  ((${#pending[@]})) || { ok "Nothing to do."; return 0; }

  local -a chosen=()
  if ((all || ${#want[@]})); then
    chosen=("${pending[@]}")
  elif ui_interactive; then
    UI_NAME_W=$width ui_pick_many chosen \
      "${mode^} which configs? (space = toggle, enter = confirm; replaced files are backed up)" "" "${items[@]}" ||
      { info "Cancelled."; return 1; }
  else
    die "not a terminal: pass modules / paths, or --all (e.g. dot configs --copy --yes kitty)"
  fi
  ((${#chosen[@]})) || { info "Nothing chosen."; return 0; }

  header "configs ($mode)"
  local key
  for key in "${chosen[@]}"; do
    i=$(_cfg_index "$key")
    printf '  %s %-*s %s%s%s\n' "$(_cfg_sym "$mode" "$i")" "$width" "$key" "$C_DIM" "$(_cfg_label "$mode" "$i")" "$C_RESET"
  done
  [[ $DOT_DRY == 1 ]] || ui_confirm "${mode^} ${#chosen[@]} config(s)?" || { info "Cancelled."; return 1; }

  local failed=0
  for key in "${chosen[@]}"; do
    _cfg_do "$mode" "$(_cfg_index "$key")" || { err "failed: $key"; failed=$((failed + 1)); }
  done
  [[ -d $BACKUP_DIR ]] && info "backups: $(pretty "$BACKUP_DIR")"
  ((failed == 0))
}

_cfg_index() { local i; for i in "${!CFG_KEYS[@]}"; do [[ ${CFG_KEYS[i]} == "$1" ]] && { echo "$i"; return; }; done; }
_cfg_dst() { printf '%s' "${CFG_KEYS[$1]/#\~/$HOME}"; }
_cfg_is_copy() { copy_rec_list | cut -f2 | grep -qxF "$(_cfg_dst "$1")"; }

# does entry <i> need anything in <mode>?
_cfg_candidate() {
  local st=${CFG_STATE[$2]}
  case $1 in
    link) [[ $st != ok ]] ;;
    copy) [[ $st != same ]] ;;
    remove) [[ $st == ok ]] || { [[ $st == same || $st == conflict ]] && _cfg_is_copy "$2"; } ;;
  esac
}

_cfg_label() {
  local st=${CFG_STATE[$2]}
  if [[ $1 == remove ]]; then
    case $st in ok) echo "linked → unlink" ;; same) echo "copy → back up + remove" ;; *) echo "edited copy → back up + remove" ;; esac
    return
  fi
  config_label "$1" "$st"
}

_cfg_sym() {
  if [[ $1 == remove ]]; then _sym -; elif [[ ${CFG_STATE[$2]} == missing ]]; then _sym +; else _sym '!'; fi
}

_cfg_do() {
  local mode=$1 i=$2 dst src=${CFG_SRC[$2]} mod=${CFG_MOD[$2]}
  dst=$(_cfg_dst "$i")
  case $mode in
    link) link_apply "$src" "$dst" && copy_rec_del "$dst" ;;
    copy) copy_apply "$src" "$dst" && copy_rec_add "$mod" "$dst" ;;
    remove)
      if [[ -L $dst ]]; then link_remove "$src" "$dst"; else _backup "$dst"; fi && copy_rec_del "$dst"
      ;;
  esac || return 1
  local -A done_word=([link]=linked [copy]=copied [remove]=removed)
  [[ $DOT_DRY == 1 ]] || ok "${done_word[$mode]} ${CFG_KEYS[i]}"
}
