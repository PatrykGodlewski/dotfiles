# shellcheck shell=bash
# CLI tests: run the real `dot` against fake package managers in a sandbox.

test_apply_installs_missing_and_records() {
  mkmod a <<<'PKGS=(x y)'
  preinstall pacman y
  dotx apply a --yes
  assert_ok
  assert_line "$FAKE_DB" "pacman x"
  assert_line "$REC" "a pacman x"
  assert_no_line "$REC" "a pacman y"   # pre-existing: never recorded
  assert_line "$SEL" a
}

test_apply_is_idempotent() {
  mkmod a <<<'PKGS=(x)'
  mkhome a .zshrc
  dotx apply a --yes; assert_ok
  local installs; installs=$(grep -c '^install' "$FAKE_LOG")
  dotx apply --yes; assert_ok
  assert_contains "$OUT" "Everything is already applied"
  assert_eq "$installs" "$(grep -c '^install' "$FAKE_LOG")" "no reinstall"
}

test_dry_run_changes_nothing() {
  mkmod a <<'EOF'
PKGS=(x)
setup() { touch "$HOME/setup-ran"; }
EOF
  mkhome a .zshrc
  echo local >"$HOME/.zshrc"
  dotx apply a --dry-run; assert_ok
  assert_contains "$OUT" "[dry]"
  assert_eq "" "$(cat "$FAKE_DB")" "packages"
  assert_no_file "$HOME/setup-ran"
  assert_eq local "$(cat "$HOME/.zshrc")" "file untouched"
  assert_no_file "$SEL"
  assert_no_file "$HOME/.local/state/dotfiles/backups"
}

test_requires_yes_when_not_interactive() {
  mkmod a <<<'PKGS=(x)'
  dotx apply a
  assert_rc_fail
  assert_eq "" "$(cat "$FAKE_DB")"
}

test_links_and_backups_on_apply() {
  mkhome a .zshrc "repo"
  mkhome a .config/nvim/init.lua
  mkmod a <<<''
  echo "old local" >"$HOME/.zshrc"
  dotx apply a --yes; assert_ok
  assert_link "$HOME/.zshrc" "$R/modules/a/home/.zshrc"
  assert_link "$HOME/.config/nvim" "$R/modules/a/home/.config/nvim"
  local b; b=$(ls -d "$HOME"/.local/state/dotfiles/backups/*)
  assert_eq "old local" "$(cat "$b/.zshrc")"
  assert_contains "$OUT" "backups:"
}

test_setup_runs_once_with_is_installed() {
  mkmod a <<'EOF'
is_installed() { [[ -f $HOME/tool ]]; }
setup() { echo run >>"$HOME/setup-count"; touch "$HOME/tool"; }
EOF
  dotx apply a --yes; assert_ok
  dotx apply a --yes; assert_ok
  assert_eq 1 "$(wc -l <"$HOME/setup-count" | tr -d ' ')"
}

test_setup_skipped_when_packages_provide_it() {
  mkmod a <<'EOF'
PKGS=(tool)
is_installed() { grep -q 'pacman tool' "$FAKE_DB"; }
setup() { touch "$HOME/setup-ran"; }
EOF
  dotx apply a --yes; assert_ok
  assert_no_file "$HOME/setup-ran"
}

test_setup_failure_is_isolated_and_stops_at_first_error() {
  mkmod bad <<'EOF'
setup() { false; touch "$HOME/after-false"; }
EOF
  mkmod good <<<'PKGS=(g)'
  dotx apply bad good --yes
  assert_rc_fail
  assert_no_file "$HOME/after-false"      # set -e inside setup()
  assert_contains "$OUT" "failed:  bad"
  assert_contains "$OUT" "done:    good"
  assert_line "$FAKE_DB" "pacman g"
}

test_package_install_failure_not_recorded() {
  mkmod a <<<'PKGS=(broken)'
  export FAKE_FAIL=broken
  dotx apply a --yes
  assert_rc_fail
  assert_no_line "$REC" "a pacman broken"
}

test_depends_applied_first() {
  mkmod lib <<<'setup() { echo lib >>"$HOME/order"; }'
  mkmod app <<'EOF'
DEPENDS=(lib)
setup() { echo app >>"$HOME/order"; }
EOF
  dotx apply app --yes; assert_ok
  assert_eq "lib app" "$(tr '\n' ' ' <"$HOME/order" | sed 's/ $//')"
  assert_line "$SEL" lib
}

test_required_module_always_applied() {
  mkmod core <<'EOF'
REQUIRED=1
PKGS=(base)
EOF
  mkmod a <<<''
  dotx apply a --yes; assert_ok
  assert_line "$FAKE_DB" "pacman base"
}

test_unsupported_module_skipped() {
  mkmod deb <<'EOF'
ONLY_ON=(debian)
PKGS=(x)
EOF
  dotx apply deb --yes
  assert_contains "$OUT" "only on debian"
  assert_eq "" "$(cat "$FAKE_DB")"
}

test_ubuntu_uses_apt_and_ignores_pacman() {
  use_os ubuntu
  mkmod a <<'EOF'
PKGS=(git)
PACMAN=(fd)
APT=(fd-find)
EOF
  dotx plan a
  assert_not_contains "$OUT" "pacman"
  dotx apply a --yes; assert_ok
  assert_line "$FAKE_DB" "apt git"
  assert_line "$FAKE_DB" "apt fd-find"
  assert_no_line "$FAKE_DB" "pacman fd"
}

test_unavailable_manager_is_skipped_not_fatal() {
  mkmod a <<'EOF'
PKGS=(x)
EXTRA=(svc)
EOF
  export FAKE_UNAVAILABLE=extra
  dotx apply a --yes; assert_ok
  assert_contains "$OUT" "extra not available here"
  assert_line "$FAKE_DB" "pacman x"
}

test_manager_ensure_only_when_installing() {
  mkmod a <<<'EXTRA=(t)'
  preinstall extra t
  dotx apply a --yes; assert_ok
  assert_no_line "$FAKE_LOG" "ensure extra"
  mkmod b <<<'EXTRA=(u)'
  dotx apply b --yes; assert_ok
  assert_line "$FAKE_LOG" "ensure extra"
}

test_plan_shows_symbols() {
  mkmod a <<<'PKGS=(x y)'
  mkhome a .zshrc
  preinstall pacman y
  echo local >"$HOME/.zshrc"
  dotx plan a; assert_ok
  assert_contains "$OUT" "+ x"
  assert_contains "$OUT" "= y"
  assert_contains "$OUT" "! ~/.zshrc"
  assert_contains "$OUT" "2 change(s)"
}

test_plan_verbose_prints_setup_code() {
  mkmod a <<<'setup() { run echo hello-from-setup; }'
  dotx plan a -v
  assert_contains "$OUT" "hello-from-setup"
}

test_remove_unlinks_and_prunes_only_unshared() {
  mkmod a <<<'PKGS=(x shared)'
  mkmod b <<<'PKGS=(shared)'
  mkhome a .zshrc
  dotx apply a b --yes; assert_ok
  dotx remove a --yes; assert_ok
  assert_no_file "$HOME/.zshrc"
  assert_no_line "$SEL" a
  assert_no_line "$FAKE_DB" "pacman x"
  assert_line "$FAKE_DB" "pacman shared"   # still needed by b
}

test_remove_never_uninstalls_preexisting() {
  preinstall pacman y
  mkmod a <<<'PKGS=(y)'
  dotx apply a --yes; assert_ok
  dotx remove a --yes; assert_ok
  assert_line "$FAKE_DB" "pacman y"
}

test_remove_keeps_user_replaced_file() {
  mkmod a <<<''
  mkhome a .zshrc
  dotx apply a --yes
  rm "$HOME/.zshrc"; echo mine >"$HOME/.zshrc"
  dotx remove a --yes; assert_ok
  assert_eq mine "$(cat "$HOME/.zshrc")"
}

test_remove_runs_teardown() {
  mkmod a <<<'teardown() { touch "$HOME/torn-down"; }'
  dotx apply a --yes
  dotx remove a --yes; assert_ok
  assert_file "$HOME/torn-down"
}

test_required_module_cannot_be_removed() {
  mkmod core <<<'REQUIRED=1'
  dotx apply core --yes
  dotx remove core --yes
  assert_contains "$OUT" "required"
  assert_line "$SEL" core
}

test_prune_after_package_dropped_from_module() {
  mkmod a <<<'PKGS=(x z)'
  dotx apply a --yes; assert_ok
  mkmod a <<<'PKGS=(x)'
  dotx plan a
  assert_contains "$OUT" "No longer needed"
  assert_contains "$OUT" "pacman:z"
  dotx prune --yes; assert_ok
  assert_no_line "$FAKE_DB" "pacman z"
  assert_line "$FAKE_DB" "pacman x"
  assert_no_line "$REC" "a pacman z"
}

test_status_states() {
  mkmod fine <<<'PKGS=(x)'
  mkmod todo <<<'PKGS=(q)'
  mkmod deb <<<'ONLY_ON=(debian)'
  dotx apply fine --yes
  dotx status; assert_ok
  assert_contains "$(grep '^fine' <<<"$OUT")" ready
  assert_contains "$(grep '^todo' <<<"$OUT")" missing
  assert_contains "$(grep '^deb' <<<"$OUT")" "only on debian"
}

test_adopt_moves_and_links() {
  mkdir -p "$HOME/.config/foo" && echo cfg >"$HOME/.config/foo/foo.conf"
  dotx adopt "$HOME/.config/foo" foo --yes; assert_ok
  assert_link "$HOME/.config/foo" "$R/modules/foo/home/.config/foo"
  assert_eq cfg "$(cat "$R/modules/foo/home/.config/foo/foo.conf")"
  assert_file "$R/modules/foo/module.sh"
  assert_line "$SEL" foo
}

test_adopt_deep_path_takes_link_unit() {
  mkdir -p "$HOME/.config/foo/sub" && echo x >"$HOME/.config/foo/sub/a.conf"
  dotx adopt "$HOME/.config/foo/sub/a.conf" foo --yes; assert_ok
  assert_link "$HOME/.config/foo" "$R/modules/foo/home/.config/foo"
}

test_adopt_refuses_bad_paths() {
  dotx adopt /etc/hostname foo --yes; assert_rc_fail "outside HOME"
  dotx adopt "$HOME/nope" foo --yes; assert_rc_fail "missing path"
  ln -s /tmp "$HOME/.already"
  dotx adopt "$HOME/.already" foo --yes; assert_rc_fail "already a symlink"
}

test_new_creates_loadable_module() {
  dotx new mytool --yes; assert_ok
  local f="$R/modules/mytool/module.sh"
  assert_file "$f"
  bash -n "$f" || _fail "generated module has syntax errors"
  load_libs; mod_load mytool
  assert_eq mytool "$DESC"
  dotx plan mytool; assert_ok
  assert_not_contains "$OUT" ".gitkeep"
  dotx new mytool --yes; assert_rc_fail "duplicate"
  dotx new 'bad name' --yes; assert_rc_fail "invalid name"
}

test_link_and_unlink_commands() {
  mkmod a <<<'PKGS=(x)'
  mkhome a .zshrc
  dotx link a; assert_ok
  assert_link "$HOME/.zshrc" "$R/modules/a/home/.zshrc"
  assert_eq "" "$(cat "$FAKE_DB")" "link must not install packages"
  dotx unlink a; assert_ok
  assert_no_file "$HOME/.zshrc"
}

test_preset_noninteractive_applies() {
  mkmod a <<<'PKGS=(x)'
  mkmod b <<<'PKGS=(y)'
  mkpreset p "# test" a b
  dotx preset p --yes; assert_ok
  assert_line "$SEL" a
  assert_line "$SEL" b
}

test_unknown_command_fails() {
  dotx frobnicate
  assert_rc_fail
  assert_contains "$OUT" "unknown command"
}

test_setup_can_call_managers_without_set_e_leaking() {
  # regression: a manager helper returning non-zero must not abort setup()
  fake_manager tricky TRICKY ''
  cat >>"$R/managers/tricky.sh" <<'EOS'
_helper() { [[ -d /definitely/not/here ]] && echo never; }
m_ensure() { _helper; echo "ensure tricky" >>"$FAKE_LOG"; }
EOS
  mkmod a <<'EOF2'
setup() { mgr tricky m_ensure; touch "$HOME/setup-finished"; }
EOF2
  dotx apply a --yes; assert_ok
  assert_file "$HOME/setup-finished"
  assert_line "$FAKE_LOG" "ensure tricky"
}

test_configs_copy_creates_real_copies_without_packages() {
  mkmod a <<<'PKGS=(x)'
  mkhome a .zshrc
  mkhome a .config/foo/cfg "v1"
  dotx configs --copy --yes a; assert_ok
  assert_file "$HOME/.zshrc"
  [[ ! -L $HOME/.config/foo && -f $HOME/.config/foo/cfg ]] || _fail "expected a real copy of ~/.config/foo"
  assert_eq "" "$(cat "$FAKE_DB")" "configs must not install packages"
  assert_no_file "$SEL"
}

test_configs_copy_updates_and_backs_up_changed() {
  mkmod a <<<''
  mkhome a .config/foo/cfg "v1"
  dotx configs --copy --yes a; assert_ok
  dotx configs --copy --yes a; assert_ok
  assert_contains "$OUT" "Nothing to do"
  mkhome a .config/foo/cfg "v2"
  dotx configs --copy --yes a; assert_ok
  assert_eq "v2" "$(cat "$HOME/.config/foo/cfg")"
  assert_eq "v1" "$(cat "$HOME"/.local/state/dotfiles/backups/*/.config/foo/cfg)" "old copy backed up"
}

test_configs_link_mode_and_path_targets() {
  mkmod a <<<''
  mkhome a .zshrc
  mkhome a .config/foo/cfg
  dotx configs --link --yes "$HOME/.config/foo"; assert_ok
  assert_link "$HOME/.config/foo" "$R/modules/a/home/.config/foo"
  assert_no_file "$HOME/.zshrc"
}

test_configs_needs_targets_when_not_interactive() {
  mkmod a <<<''
  mkhome a .zshrc
  dotx configs --copy --yes; assert_rc_fail "no targets"
  dotx configs --copy --all --yes; assert_ok
  assert_file "$HOME/.zshrc"
}
