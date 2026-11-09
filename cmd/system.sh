# shellcheck shell=bash
# update, doctor and the interactive menu.

# dot update: git pull, then refresh copied configs and re-apply the selection
cmd_update() {
  header "Updating $(pretty "$DOT_ROOT")"
  run git -C "$DOT_ROOT" pull --ff-only || die "git pull failed (local changes?)"
  # re-exec so the freshly pulled code does the rest
  local -a flags=()
  [[ $DOT_YES == 1 ]] && flags+=(--yes)
  [[ $DOT_DRY == 1 ]] && flags+=(--dry-run)
  rm -rf "$DOT_RUN_DIR" # exec skips the EXIT trap
  exec "$DOT_ROOT/dot" refresh --then-apply "${flags[@]}"
}

# dot refresh: re-copy configs whose repo version changed since they were
# copied. Copies you edited here are never overwritten (dot sync handles them).
cmd_refresh() {
  local then_apply=0 mod dst hash n=0
  [[ ${1:-} == --then-apply ]] && then_apply=1
  header "Refreshing copied configs"
  while IFS=$'\t' read -r mod dst hash; do
    case $(copy_status "$mod" "$dst" "$hash") in
      repo)
        copy_apply "$(config_src "$mod" "$dst")" "$dst" && copy_rec_add "$mod" "$dst" &&
          ok "updated $(pretty "$dst")"
        n=$((n + 1)) ;;
      local) info "$(pretty "$dst"): edited here — kept (record it with: dot sync)" ;;
      both) warn "$(pretty "$dst"): changed here and in the repo — kept; see: dot sync" ;;
      gone) warn "$(pretty "$dst"): no longer in module $mod" ;;
    esac
  done < <(copy_rec_list)
  ((n)) || ok "copied configs are up to date"
  [[ -d $BACKUP_DIR ]] && info "backups: $(pretty "$BACKUP_DIR")"
  if ((then_apply)) && [[ -n $(sel_get) ]]; then cmd_apply; fi
  return 0
}

cmd_doctor() {
  header "dot doctor"
  local m
  ok "OS: $(os_summary)  tags: ${OS_TAGS[*]}"
  [[ $OS_FAMILY == unknown ]] && err "unsupported distro family — only Arch and Debian/Ubuntu based distros are handled"
  ok "bash ${BASH_VERSION}"
  ok "repo: $(pretty "$DOT_ROOT")"
  if [[ -n $(git -C "$DOT_ROOT" status --porcelain 2>/dev/null) ]]; then
    warn "repo has uncommitted changes (git -C $(pretty "$DOT_ROOT") status)"
  fi
  if has sudo || [[ $EUID -eq 0 ]]; then ok "sudo available"; else err "sudo not found"; fi
  if has gum; then ok "gum $(gum --version 2>/dev/null | awk '{print $3}')"; else warn "gum missing — plain prompts are used (dot apply core)"; fi
  [[ ":$PATH:" == *":$HOME/.local/bin:"* ]] && ok "~/.local/bin in PATH"
  has dot || warn "'dot' is not on PATH — link it: ln -s $(pretty "$DOT_ROOT/dot") ~/.local/bin/dot"
  for m in "${MGR_ORDER[@]}"; do
    mgr_relevant "$m" || continue
    if mgr "$m" m_available; then ok "manager $m: ${MGR_DESC[$m]}"; else info "manager $m: not available here"; fi
  done
  local broken
  broken=$(find "$HOME" -maxdepth 3 -xtype l -lname "$DOT_ROOT/*" 2>/dev/null)
  if [[ -n $broken ]]; then
    warn "broken links into the repo (module file removed?):"
    sed 's/^/    /' <<<"$broken"
  else
    ok "no broken links into the repo"
  fi
  info "selected: $(sel_get | tr '\n' ' ')"
}

cmd_menu() {
  ui_interactive || { usage; return; }
  [[ -z $(sel_get) ]] && info "Nothing selected on this machine yet — start with 'configs' or 'preset'."
  local choice
  local -a extra=()
  om_available && extra=("omarchy"$'\t'"Omarchy profile: defaults / theme / installers / preinstalls")
  while true; do
    choice=$(ui_choose_one "dot — $(os_summary)" \
      "configs"$'\t'"Pick configs to copy or link (no packages)" \
      "sync"$'\t'"Record changes made on this machine into the repo (shows diffs)" \
      "${extra[@]}" \
      "status"$'\t'"What is selected / installed / linked" \
      "preset"$'\t'"Start from a preset (desktop / headless / ...)" \
      "select"$'\t'"Choose modules for this machine" \
      "apply"$'\t'"Apply the saved selection" \
      "plan"$'\t'"Dry run: show what apply would do" \
      "remove"$'\t'"Remove modules" \
      "new"$'\t'"Create a new module" \
      "adopt"$'\t'"Move an existing config into a module" \
      "prune"$'\t'"Uninstall packages no longer needed" \
      "update"$'\t'"git pull + apply" \
      "doctor"$'\t'"Check the environment" \
      "quit"$'\t'"") || break
    case $choice in
      quit | '') break ;;
      adopt)
        local p; p=$(ui_input "Path to adopt (e.g. ~/.config/foo)")
        [[ -n $p ]] && cmd_adopt "${p/#\~/$HOME}"
        ;;
      *) "cmd_$choice" ;;
    esac
    printf '\n'
    ui_confirm "Back to menu?" || break
  done
}
