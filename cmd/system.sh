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
  exec "$DOT_SELF" refresh --then-apply "${flags[@]}"
}

# dot repo [path]: show which dotfiles repo is used, or remember one
cmd_repo() {
  local path=${1:-} found
  if [[ -z $path ]]; then
    found=$(repo_find) || { repo_require; return 1; }
    printf '%s\n' "${found%%$'\t'*}"
    info "${found#*$'\t'}"
    return 0
  fi
  path=$(realpath -m "${path/#\~/$HOME}")
  is_dotfiles_repo "$path" || die "$(pretty "$path") is not a dotfiles repo (no modules/ inside)"
  [[ $DOT_DRY == 1 ]] && { info "would remember $(pretty "$path")"; return 0; }
  mkdir -p "$DOT_CONFIG_DIR"
  printf '%s\n' "$path" >"$REPO_FILE"
  ok "dot now uses $(pretty "$path")"
}

# dot self-update: fetch and reinstall the latest tool (your repo is untouched)
DOT_INSTALL_URL=${DOT_INSTALL_URL:-https://raw.githubusercontent.com/PatrykGodlewski/dotfiles/main/install.sh}
cmd_self_update() {
  if [[ $DOT_SELF != "$HOME/.local/bin/dot" ]]; then
    info "running from a checkout ($(pretty "$DOT_SELF")) — update it with git pull"
    return 0
  fi
  header "Reinstalling dot"
  rm -rf "$DOT_RUN_DIR" # the installer replaces the files this process came from
  run_sh "curl -fsSL '$DOT_INSTALL_URL' | bash"
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
  ok "tool: $(pretty "$DOT_SELF")  (files: $(pretty "$DOT_HOME"))"
  local found
  if found=$(repo_find); then
    ok "repo: $(pretty "${found%%$'\t'*}")  (${found#*$'\t'})"
    if [[ -n $(git -C "$DOT_ROOT" status --porcelain 2>/dev/null) ]]; then
      warn "repo has uncommitted changes (git -C $(pretty "$DOT_ROOT") status)"
    fi
  else
    warn "no dotfiles repo found — clone one, or: dot repo <path>"
  fi
  if has sudo || [[ $EUID -eq 0 ]]; then ok "sudo available"; else err "sudo not found"; fi
  if has gum; then ok "gum $(gum --version 2>/dev/null | awk '{print $3}')"; else warn "gum missing — plain prompts are used (dot apply core)"; fi
  [[ ":$PATH:" == *":$HOME/.local/bin:"* ]] && ok "~/.local/bin in PATH"
  if [[ $(command -v dot) != "$HOME/.local/bin/dot" ]]; then
    warn "'dot' resolves to $(command -v dot || echo nothing) — install.sh puts it in ~/.local/bin (first in PATH)"
  fi
  for m in "${MGR_ORDER[@]}"; do
    mgr_relevant "$m" || continue
    if mgr "$m" m_available; then ok "manager $m: ${MGR_DESC[$m]}"; else info "manager $m: not available here"; fi
  done
  local broken
  [[ -n $DOT_ROOT ]] && broken=$(find "$HOME" -maxdepth 3 -xtype l -lname "$DOT_ROOT/*" 2>/dev/null)
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
  local -a omarchy=()
  om_available && omarchy=(
    "$(ui_sep "Omarchy")"
    "omarchy"$'\t'"Defaults, theme, installers, preinstalls (profile)"
  )
  while true; do
    choice=$(ui_choose_one "dot — $(os_summary)" \
      "$(ui_sep "Configs")" \
      "configs"$'\t'"Copy / link / remove configs (no packages)" \
      "sync"$'\t'"Record changes made on this machine into the repo" \
      "refresh"$'\t'"Re-copy configs the repo changed" \
      "${omarchy[@]}" \
      "$(ui_sep "Apps & modules")" \
      "status"$'\t'"What is selected / installed / linked" \
      "preset"$'\t'"Start from a preset (desktop / headless / ...)" \
      "select"$'\t'"Choose modules for this machine" \
      "plan"$'\t'"Dry run: show what apply would do" \
      "apply"$'\t'"Apply the saved selection" \
      "remove"$'\t'"Remove modules" \
      "prune"$'\t'"Uninstall packages no longer needed" \
      "$(ui_sep "Dotfiles repo")" \
      "update"$'\t'"git pull, refresh copied configs, re-apply" \
      "new"$'\t'"Create a new module" \
      "adopt"$'\t'"Move an existing config into a module" \
      "$(ui_sep "dot")" \
      "doctor"$'\t'"Check the environment" \
      "self-update"$'\t'"Install the latest dot" \
      "quit"$'\t'"") || break
    [[ $choice == quit ]] && break
    # subshell: a command that fails (die/exit) returns here instead of
    # ending the menu
    (
      if [[ $choice == adopt ]]; then
        p=$(ui_input "Path to adopt (e.g. ~/.config/foo)")
        [[ -z $p ]] || cmd_adopt "${p/#\~/$HOME}"
      else
        "cmd_${choice//-/_}"
      fi
    ) || true
    printf '\n'
  done
}
