# shellcheck shell=bash
# dot sync [--omarchy|--configs] — bring changes made on this machine (by hand
# or through the Omarchy menu) back into the repo:
#   --omarchy  defaults, theme, font, packages and apps added / removed
#              -> modules/omarchy/profile
#   --configs  configs dot copied here and you edited since -> their module;
#              new configs (customized Omarchy ones, small untracked ones)
# Every diff is shown first. Only the repo is written, never the system.

cmd_sync() {
  local scope=all a
  for a in "$@"; do
    case $a in
      --omarchy) scope=omarchy ;;
      --configs) scope=configs ;;
      *) die "usage: dot sync [--omarchy|--configs]" ;;
    esac
  done

  [[ $scope == omarchy ]] && om_require
  local -a types=() payloads=() labels=()
  local t p l
  while IFS=$'\t' read -r t p l; do
    types+=("$t") payloads+=("$p") labels+=("$l")
  done < <(
    [[ $scope != configs ]] && sync_omarchy_changes
    [[ $scope != omarchy ]] && sync_config_changes
  )
  if ((${#types[@]} == 0)); then
    ok "Nothing to sync — the repo matches this machine."
    _sync_git_hint
    return 0
  fi

  _sync_show_diffs

  local i
  local -a items=() pre=() chosen=()
  header "Changes"
  for i in "${!types[@]}"; do
    items+=("$((i + 1))"$'\t'"${labels[i]}")
    if _sync_opt_in "${types[i]}"; then
      printf '  %s %s %s(opt-in)%s\n' "$(_sym '~')" "${labels[i]}" "$C_DIM" "$C_RESET"
    else
      printf '  %s %s\n' "$(_sym +)" "${labels[i]}"
      pre+=("$((i + 1))")
    fi
  done
  if ui_interactive && [[ $DOT_YES != 1 ]]; then
    UI_NAME_W=4 ui_pick_many chosen "Record which changes in the repo? (space = toggle, enter = confirm)" \
      "${pre[*]}" "${items[@]}" || { info "Cancelled."; return 1; }
  elif [[ $DOT_YES == 1 ]]; then
    chosen=("${pre[@]}")
  else
    die "not a terminal: pass --yes to record the changes not marked opt-in"
  fi
  _sync_offer_ignore
  ((${#chosen[@]})) || { info "Nothing chosen."; return 0; }

  local -a profile_cmds=() configs=() new=()
  for i in "${chosen[@]}"; do
    i=$((i - 1))
    case ${types[i]} in
      profile) profile_cmds+=("${payloads[i]}") ;;
      config | conflict) configs+=("${payloads[i]}") ;;
      newconfig) new+=("${payloads[i]}") ;;
    esac
  done

  if ((${#profile_cmds[@]})); then
    local f="$DOT_RUN_DIR/profile.new"
    profile_with_set "$PROFILE_FILE" "${profile_cmds[@]}" >"$f"
    local shown=0
    cmp -s "$f" "$DOT_RUN_DIR/profile.preview" && shown=1 # same as the preview above
    profile_write "$PROFILE_FILE" "$f" "$shown" || true
  fi
  if ((${#configs[@]} + ${#new[@]})); then
    [[ $DOT_DRY == 1 ]] || ui_confirm "Copy $((${#configs[@]} + ${#new[@]})) config(s) into the repo?" ||
      { info "Configs not copied."; _sync_git_hint; return 0; }
    for p in "${configs[@]}"; do _sync_config_back "$p"; done
    for p in "${new[@]}"; do _sync_capture "$p"; done
  fi
  _sync_git_hint
}

_sync_show_diffs() {
  local i dst mod src
  local -a cmds=()
  for i in "${!types[@]}"; do [[ ${types[i]} == profile ]] && cmds+=("${payloads[i]}"); done
  if ((${#cmds[@]})); then
    header "Omarchy profile (if everything is recorded)"
    profile_with_set "$PROFILE_FILE" "${cmds[@]}" >"$DOT_RUN_DIR/profile.preview"
    show_diff "$PROFILE_FILE" "$DOT_RUN_DIR/profile.preview" "$(pretty "$PROFILE_FILE")"
  fi
  for i in "${!types[@]}"; do
    dst=${payloads[i]/#\~/$HOME}
    case ${types[i]} in
      config | conflict)
        mod=$(_copy_module "$dst") src=$(config_src "$mod" "$dst")
        header "${payloads[i]}  (repo: modules/$mod → this machine)"
        show_diff "$src" "$dst" "" 60
        ;;
      newconfig)
        header "${labels[i]} → modules/$(sync_target_module "$dst")"
        if [[ -e $OM_SHARE/config/${dst##*/} ]]; then
          show_diff "$OM_SHARE/config/${dst##*/}" "$dst" "" 40 # vs the Omarchy default
        else
          find "$dst" -maxdepth 2 | head -n 10 | sed "s|^$HOME|  ~|"
        fi
        ;;
    esac
  done
}

# interactive only: silence the changes that were left unpicked
_sync_offer_ignore() {
  ui_interactive && [[ $DOT_YES != 1 ]] || return 0
  local i l
  local -a lines=()
  for i in "${!types[@]}"; do
    in_list "$((i + 1))" "${chosen[@]}" && continue
    l=$(sync_ignore_line "${types[i]}" "${payloads[i]}")
    [[ -n $l ]] && lines+=("$l")
  done
  ((${#lines[@]})) || return 0
  printf '\nNot picked: %s\n' "$(printf '%s, ' "${lines[@]}" | sed 's/, $//')"
  ui_confirm "Ignore these in future syncs? (adds them to sync.ignore)" && sync_ignore_add "${lines[@]}"
  return 0
}

# new configs and conflicts are never recorded unless picked
_sync_opt_in() { [[ $1 == newconfig || $1 == conflict ]]; }

_copy_module() { # module that recorded <dst> as a copy
  awk -F'\t' -v d="$1" '$2 == d { print $1; exit }' "$COPY_FILE" 2>/dev/null
}

# local edits of a copied config -> repo
_sync_config_back() {
  local dst=${1/#\~/$HOME} mod src
  mod=$(_copy_module "$dst") && src=$(config_src "$mod" "$dst") || { err "not managed: $1"; return 1; }
  run rm -rf "$src" && run cp -a "$dst" "$src" || return 1
  copy_rec_add "$mod" "$dst" # repo and copy agree again
  ok "updated modules/$mod from $1"
}

# untracked config -> new or existing module (stays in place as a managed copy)
_sync_capture() {
  local dst=${1/#\~/$HOME} mod rel dest
  mod=$(sync_target_module "$dst")
  rel=${dst#"$HOME"/}
  dest="$DOT_ROOT/modules/$mod/home/$rel"
  [[ -e $dest ]] && { warn "modules/$mod/home/$rel already exists — skipped $1"; return 0; }
  mod_exists "$mod" || new_module "$mod" "${rel##*/} config (captured by dot sync)" "" "" "" || return 1
  run mkdir -p "$(dirname "$dest")" && run cp -a "$dst" "$dest" || return 1
  [[ $DOT_DRY == 1 ]] || rm -f "$DOT_ROOT/modules/$mod/home/.gitkeep"
  copy_rec_add "$mod" "$dst"
  ok "captured $1 → modules/$mod"
}

_sync_git_hint() {
  local st
  st=$(git -C "$DOT_ROOT" status --short -- modules sync.ignore 2>/dev/null)
  [[ -n $st ]] || return 0
  printf '\n%sUncommitted in the repo:%s\n%s\n' "$C_BOLD" "$C_RESET" "$(sed 's/^/  /' <<<"$st")"
  info "review: git -C $(pretty "$DOT_ROOT") diff    commit: git -C $(pretty "$DOT_ROOT") add -A && git -C $(pretty "$DOT_ROOT") commit -m sync"
}
