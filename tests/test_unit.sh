# shellcheck shell=bash
# Unit tests: OS detection, link rules, presets, resolution, package mapping, state.

# ---------- OS detection ----------
_family_of() { use_os "$1"; load_libs; echo "$OS_FAMILY"; }
test_os_arch_family()        { assert_eq arch "$(_family_of arch)"; }
test_os_endeavouros_is_arch(){ assert_eq arch "$(_family_of endeavouros)"; }
test_os_manjaro_is_arch()    { assert_eq arch "$(_family_of manjaro)"; }
test_os_ubuntu_is_debian()   { assert_eq debian "$(_family_of ubuntu)"; }
test_os_debian_is_debian()   { assert_eq debian "$(_family_of debian)"; }
test_os_pop_is_debian()      { assert_eq debian "$(_family_of pop)"; }
test_os_fedora_unknown()     { assert_eq unknown "$(_family_of fedora)"; }
test_os_wsl_tag() {
  DOT_WSL=1 load_libs
  assert_contains " ${OS_TAGS[*]} " " wsl "
  DOT_WSL=0 detect_os
  assert_not_contains " ${OS_TAGS[*]} " " wsl "
}

# ---------- link rules ----------
test_links_granularity() {
  mkhome m .zshrc
  mkhome m .config/nvim/init.lua
  mkhome m .config/nvim/lua/x.lua
  mkhome m .config/starship.toml
  mkhome m .local/bin/tool
  mkhome m .local/scripts/a
  mkhome m .local/share/fonts/f.ttf
  touch "$R/modules/m/home/.gitkeep"
  load_libs
  local got; got=$(links_of m | cut -f2 | sed "s|$HOME|~|" | sort | tr '\n' ' ')
  assert_eq "~/.config/nvim ~/.config/starship.toml ~/.local/bin/tool ~/.local/scripts ~/.local/share/fonts ~/.zshrc " "$got"
}

test_link_unit() {
  load_libs
  assert_eq .config/foo "$(link_unit .config/foo/bar/baz.conf)"
  assert_eq .zshrc "$(link_unit .zshrc)"
  assert_eq .local/bin/x "$(link_unit .local/bin/x)"
  assert_eq .local/share/fonts "$(link_unit .local/share/fonts/a.ttf)"
}

test_link_state_and_apply_backup() {
  mkhome m .zshrc "repo version"
  load_libs
  local src="$R/modules/m/home/.zshrc" dst="$HOME/.zshrc"
  assert_eq missing "$(link_state "$src" "$dst")"
  echo "my local edits" >"$dst"
  assert_eq conflict "$(link_state "$src" "$dst")"
  link_apply "$src" "$dst" >/dev/null
  assert_link "$dst" "$src"
  assert_eq ok "$(link_state "$src" "$dst")"
  assert_eq "my local edits" "$(cat "$BACKUP_DIR/.zshrc")" "backup content"
}

test_link_state_same_and_foreign() {
  mkhome m .config/app/a.conf "same"
  load_libs
  local src="$R/modules/m/home/.config/app" dst="$HOME/.config/app"
  mkdir -p "$dst" && echo same >"$dst/a.conf"
  assert_eq same "$(link_state "$src" "$dst")"
  rm -rf "$dst"; ln -s /somewhere/else "$dst"
  assert_eq foreign "$(link_state "$src" "$dst")"
}

test_link_remove_only_ours() {
  mkhome m .zshrc
  load_libs
  local src="$R/modules/m/home/.zshrc" dst="$HOME/.zshrc"
  echo mine >"$dst"
  link_remove "$src" "$dst" >/dev/null
  assert_file "$dst"
  rm "$dst"; ln -s /other "$dst"
  link_remove "$src" "$dst" >/dev/null
  assert_link "$dst" /other
}

# ---------- presets / resolution ----------
test_preset_includes_comments_dedupe() {
  mkpreset base "# Base preset" a b
  mkpreset big "# Big one" "@base" "c   # trailing comment" "" b d
  load_libs
  assert_eq "a b c d" "$(preset_modules big | tr '\n' ' ' | sed 's/ $//')"
  assert_eq "Big one" "$(preset_desc big)"
}

test_resolve_deps_required_dedupe_cycles() {
  mkmod core <<<'REQUIRED=1'
  mkmod lib <<<'DEPENDS=(app)'   # cycle lib <-> app
  mkmod app <<<'DEPENDS=(lib)'
  mkmod ui <<<'DEPENDS=(lib)'
  load_libs
  resolve ui app ui 2>/dev/null
  assert_eq "core app lib ui" "${RESOLVED[*]}"
}

test_resolve_preset_and_unknown() {
  mkmod a <<<''
  mkmod b <<<'DEPENDS=(a)'
  mkpreset p b
  load_libs
  local warn_out
  warn_out=$(resolve @p ghost 2>&1)
  assert_contains "$warn_out" "unknown module: ghost"
  resolve @p ghost 2>/dev/null
  assert_eq "a b" "${RESOLVED[*]}"
}

test_supported_only_on_skip_on() {
  mkmod archonly <<<'ONLY_ON=(arch)'
  mkmod nowsl <<<'SKIP_ON=(wsl)'
  load_libs
  mod_load archonly; mod_supported >/dev/null || _fail "archonly should be supported on arch"
  mod_load nowsl; mod_supported >/dev/null || _fail "nowsl supported outside wsl"
  use_os ubuntu; DOT_WSL=1 detect_os
  mod_load archonly; mod_supported >/dev/null && _fail "archonly must be unsupported on ubuntu"
  mod_load nowsl; assert_eq "skipped on wsl" "$(mod_supported)"
}

test_pkgs_map_to_native_manager() {
  mkmod m <<'EOF'
PKGS=(git)
PACMAN=(fd)
APT=(fd-find)
EXTRA=(tool)
EOF
  load_libs
  mod_load m
  assert_eq "git fd" "$(mod_pkgs pacman | tr '\n' ' ' | sed 's/ $//')" arch-pacman
  assert_eq "fd-find" "$(mod_pkgs apt | tr '\n' ' ' | sed 's/ $//')" "arch-apt (no PKGS)"
  assert_eq "tool" "$(mod_pkgs extra)"
  use_os ubuntu; detect_os; mod_load m
  assert_eq "git fd-find" "$(mod_pkgs apt | tr '\n' ' ' | sed 's/ $//')" ubuntu-apt
  mgr_relevant pacman && _fail "pacman must not be relevant on ubuntu"
  mgr_relevant extra || _fail "family-less manager is always relevant"
}

test_mod_load_resets_previous_module() {
  mkmod one <<'EOF'
DESC=one
PKGS=(a)
DEPENDS=(x)
setup() { :; }
EOF
  mkmod two <<<'DESC=two'
  load_libs
  mod_load one; mod_load two
  assert_eq two "$DESC"
  assert_eq 0 "${#PKGS[@]}" "PKGS leaked"
  assert_eq 0 "${#DEPENDS[@]}" "DEPENDS leaked"
  mod_has_hook setup && _fail "setup() leaked from previous module"
  return 0
}

# ---------- state / utils ----------
test_selection_sorted_unique_and_dry() {
  load_libs
  sel_add b a
  sel_add a c
  assert_eq "a b c" "$(sel_get | tr '\n' ' ' | sed 's/ $//')"
  sel_del b
  assert_eq "a c" "$(sel_get | tr '\n' ' ' | sed 's/ $//')"
  DOT_DRY=1 sel_add zzz
  assert_not_contains "$(sel_get)" zzz "dry run must not write selection"
}

test_records_dedupe_and_delete() {
  load_libs
  rec_add m pacman x; rec_add m pacman x; rec_add m pacman y
  assert_eq 2 "$(rec_list | wc -l | tr -d ' ')"
  rec_del pacman x
  assert_eq "m pacman y" "$(rec_list)"
}

test_version_ge() {
  load_libs
  version_ge 0.12.6 0.11 || _fail "0.12.6 >= 0.11"
  version_ge 0.11 0.11 || _fail "equal"
  version_ge 0.9.5 0.11 && _fail "0.9.5 < 0.11"
  version_ge "" 0.11 && _fail "empty version"
  return 0
}

test_ui_fallback_picker_toggles() {
  command -v script >/dev/null || { echo "skip: no 'script'"; return 0; }
  local out="$T/picked" prog="$T/picker.sh"
  {
    printf 'for f in core os ui; do source "%s/lib/$f.sh"; done\n' "$R"
    printf "ui_choose_many Pick a \$'a\\\\tA' \$'b\\\\tB' \$'c\\\\tC' >'%s'\n" "$out"
  } >"$prog"
  # preselected: a ; user toggles 1 (a off) and 3 (c on), then Enter
  (sleep 0.5; printf '1 3\n'; sleep 0.3; printf '\n') |
    timeout 10 script -qec "bash $prog" /dev/null >/dev/null 2>&1
  assert_eq "c" "$(cat "$out")"
}
