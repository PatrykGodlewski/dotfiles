# shellcheck shell=bash
# install.sh and finding the dotfiles repo. The installer runs from a local
# copy (DOT_SOURCE), so nothing is downloaded.

install_dot() { OUT=$(DOT_SOURCE=${1:-$REPO} bash "$REPO/install.sh" </dev/null 2>&1); RC=$?; }
# run the installed tool from a directory that is not a repo
dotinst() { OUT=$(cd "$T" && "$HOME/.local/bin/dot" "$@" </dev/null 2>&1); RC=$?; }

test_install_creates_standalone_tool() {
  install_dot; assert_ok
  [[ -f $HOME/.local/bin/dot && ! -L $HOME/.local/bin/dot ]] || _fail "~/.local/bin/dot must be a real file"
  assert_file "$HOME/.local/share/dot/lib/core.sh"
  assert_file "$HOME/.local/share/dot/managers/pacman.sh"
  assert_no_file "$HOME/.local/share/dot/modules"   # your dotfiles are not part of the tool
  dotinst help; assert_ok
  assert_contains "$OUT" "Repo: none"
}

test_install_from_tarball_replaces_old_symlink() {
  mkdir -p "$T/src/dotfiles-main" "$HOME/.local/bin"
  cp -R "$REPO/dot" "$REPO/lib" "$REPO/cmd" "$REPO/managers" "$REPO/templates" "$T/src/dotfiles-main/"
  tar -czf "$T/dot.tar.gz" -C "$T/src" dotfiles-main
  ln -s /nonexistent/dot "$HOME/.local/bin/dot"
  install_dot "$T/dot.tar.gz"; assert_ok
  [[ -f $HOME/.local/bin/dot && ! -L $HOME/.local/bin/dot ]] || _fail "old symlink must be replaced"
  dotinst help; assert_ok
}

test_install_rejects_bad_source_and_keeps_old_install() {
  install_dot; assert_ok
  mkdir -p "$T/empty"
  install_dot "$T/empty"; assert_rc_fail "not a dot source"
  assert_file "$HOME/.local/share/dot/lib/core.sh"
}

test_install_path_line_added_once() {
  echo '# mine' >"$HOME/.bashrc"
  install_dot; assert_ok
  install_dot; assert_ok
  assert_eq 1 "$(grep -c 'dotfiles: ~/.local/bin first' "$HOME/.bashrc")"
}

test_installed_tool_needs_a_repo_then_finds_it() {
  install_dot; assert_ok
  rm -rf "$HOME/.local/share/dot/managers" # use the sandbox's fake package managers
  cp -R "$R/managers" "$HOME/.local/share/dot/managers"
  dotinst status; assert_rc_fail "no repo yet"
  assert_contains "$OUT" "no dotfiles repo found"
  mkmod a <<<'PKGS=(x)'
  dotinst repo "$R"; assert_ok
  assert_line "$HOME/.config/dotfiles/repo" "$R"
  dotinst status; assert_ok
  assert_contains "$OUT" "a "
  dotinst repo; assert_ok
  assert_contains "$OUT" "set with 'dot repo'"
}

test_repo_discovery_order() {
  install_dot; assert_ok
  mkdir -p "$HOME/Projects/dotfiles/modules" "$T/saved/modules" "$T/env/modules"
  dotinst repo; assert_contains "$OUT" "$HOME/Projects/dotfiles"
  assert_contains "$OUT" "default location"
  dotinst repo "$T/saved"; assert_ok
  dotinst repo; assert_contains "$OUT" "$T/saved"
  OUT=$(cd "$T" && DOTFILES_DIR=$T/env "$HOME/.local/bin/dot" repo 2>&1)
  assert_contains "$OUT" "$T/env"
  assert_contains "$OUT" "DOTFILES_DIR"
}

test_repo_rejects_non_repo() {
  install_dot; assert_ok
  mkdir -p "$T/notrepo"
  dotinst repo "$T/notrepo"; assert_rc_fail
  assert_no_file "$HOME/.config/dotfiles/repo"
}

test_checkout_uses_itself_and_self_update_points_to_git() {
  dotx repo; assert_ok
  assert_contains "$OUT" "the checkout dot runs from"
  dotx self-update; assert_ok
  assert_contains "$OUT" "git pull"
}
