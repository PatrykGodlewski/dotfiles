# shellcheck shell=bash
# Omarchy integration + sync. A stateful fake `omarchy` keeps its state in
# $T/om/ and logs every call that would change the system to $T/om/log, so a
# test can assert exactly what dot asked omarchy to do (usually: nothing).

om_setup() {
  local S=$T/om
  mkdir -p "$S" "$OMARCHY_PATH"/{applications,config,install} "$HOME/.local/share/applications" "$R/modules/omarchy"
  echo chromium >"$S/default-browser"; echo ghostty >"$S/default-terminal"
  echo zeditor >"$S/default-editor"; : >"$S/default-agent"
  echo "Tokyo Night" >"$S/theme"; echo "JetBrainsMono Nerd Font" >"$S/font"
  printf 'Tokyo Night\nCatppuccin Latte\n' >"$S/themes"
  printf 'JetBrainsMono Nerd Font\nFira Code\n' >"$S/fonts"
  printf 'git\nobsidian\npinta\n' >"$S/pkgs" # installed      (pacman -Qq)
  : >"$S/explicit"; : >"$S/foreign"        # explicit / AUR   (pacman -Qqe / -Qqm)
  printf 'obsidian\npinta\n' >"$S/defaults" # omarchy-pkg-defaults
  : >"$S/log"
  cat >"$S/catalog.json" <<'J'
{"ok":true,"commands":[
 {"route":"omarchy default browser","args":"[chromium|firefox]","summary":"Set the browser","hidden":false},
 {"route":"omarchy install dev-env","args":"<node|go>","summary":"Dev env","hidden":false},
 {"route":"omarchy install service tailscale","args":"","summary":"Tailscale","hidden":false},
 {"route":"omarchy install app","args":"<display-name> <packages>","summary":"free-form","hidden":false},
 {"route":"omarchy install dictation voxtype","args":"[--background]","summary":"flags only","hidden":false},
 {"route":"omarchy install secret","args":"","summary":"hidden","hidden":true},
 {"route":"omarchy remove dev env","args":"<node|go>","summary":"Remove dev env","hidden":false},
 {"route":"omarchy theme set","args":"<theme-name>","summary":"not part of the catalog","hidden":false}]}
J
  fake_cmd omarchy <<'SH'
S=$T/om
log() { printf '%s\n' "$*" >>"$S/log"; }
case "$1 ${2:-}" in
  "default "*)
    [[ -z ${3:-} ]] && { cat "$S/default-$2"; exit 0; }
    log "$@"; v=$3; [[ $2 == editor && $v == zed ]] && v=zeditor; echo "$v" >"$S/default-$2" ;;
  "theme current") cat "$S/theme" ;;
  "theme list") cat "$S/themes" ;;
  "theme set") log "$@"; echo "${*:3}" >"$S/theme" ;;
  "font current") cat "$S/font" ;;
  "font list") cat "$S/fonts" ;;
  "font set") log "$@"; echo "${*:3}" >"$S/font" ;;
  "pkg present") shift 2; for p in "$@"; do grep -qx "$p" "$S/pkgs" || exit 1; done ;;
  "commands --json") cat "$S/catalog.json" ;;
  "webapp remove" | "tui remove") log "$@"; rm -f "$HOME/.local/share/applications/${*:3}.desktop" ;;
  *) log "$@" ;;
esac
SH
  fake_cmd pacman <<'SH'
case $1 in
  -Qq) cat "$T/om/pkgs" ;; -Qqe) cat "$T/om/explicit" ;; -Qqm) cat "$T/om/foreign" ;;
  *) echo "pacman $*" >>"$T/traps.log"; exit 97 ;;
esac
SH
  fake_cmd omarchy-pkg-defaults <<<'cat "$T/om/defaults"'
  echo 'ONLY_ON=(omarchy)' >"$R/modules/omarchy/module.sh"
  : >"$R/modules/omarchy/profile"
  use_omarchy_os
}

use_omarchy_os() {
  printf 'ID=omarchy\nID_LIKE=arch\nPRETTY_NAME="Omarchy"\n' >"$T/os-release"
}

profile() { cat >"$R/modules/omarchy/profile"; }
om_log() { cat "$T/om/log"; }

# mkapp <dir> <name> webapp|tui
mkapp() {
  local exec='omarchy-launch-webapp https://example.com'
  [[ $3 == tui ]] && exec='xdg-terminal-exec -e lazydocker'
  printf '[Desktop Entry]\nName=%s\nExec=%s\n' "$2" "$exec" >"$1/$2.desktop"
}

# ---------------------------------------------------------------- safety
test_traps_catch_system_commands() {
  sudo pacman -S firefox; local rc=$?
  assert_eq 97 "$rc" "trapped command must fail"
  assert_line "$T/traps.log" "sudo pacman -S firefox"
  : >"$T/traps.log" # this test hit a trap on purpose
}

test_omarchy_never_runs_without_explicit_apply() {
  om_setup
  profile <<<'default browser firefox'
  dotx omarchy; assert_ok
  dotx omarchy status; assert_ok
  dotx omarchy --yes; assert_ok
  assert_contains "$OUT" "+ omarchy default browser firefox"
  assert_eq "" "$(om_log)" "status must not run anything"
}

test_omarchy_disabled_or_missing() {
  om_setup
  DOT_OMARCHY=0 dotx omarchy status; assert_rc_fail "integration disabled"
  assert_contains "$OUT" "not an Omarchy system"
}

# ---------------------------------------------------------------- apply
test_omarchy_apply_yes_runs_only_pending_lines() {
  om_setup
  printf 'git\nobsidian\n' >"$T/om/pkgs" # pinta already gone
  mkapp "$HOME/.local/share/applications" HEY webapp
  profile <<'P'
# comment
default browser chromium
omarchy default editor zed
theme set "tokyo night"
font set "JetBrainsMono Nerd Font"
default browser firefox   # trailing comment
theme set "Catppuccin Latte"
webapp remove HEY
webapp remove Basecamp
pkg drop obsidian
pkg drop pinta
install dev-env node
P
  dotx omarchy apply --yes; assert_ok
  assert_eq $'default browser firefox\ntheme set Catppuccin Latte\nwebapp remove HEY\npkg drop obsidian' "$(om_log)"
  assert_contains "$OUT" "line 6 repeats 'default browser' from line 2"
  profile <<'P'
default browser firefox
install dev-env node
P
  : >"$T/om/log"
  dotx omarchy apply --yes --all; assert_ok
  assert_eq "install dev-env node" "$(om_log)" "--all adds the uncheckable lines"
}

test_omarchy_apply_needs_yes_without_terminal() {
  om_setup
  profile <<<'default browser firefox'
  dotx omarchy apply; assert_rc_fail "no terminal, no --yes"
  assert_eq "" "$(om_log)"
}

test_omarchy_apply_interactive_preselects_nothing() {
  om_setup
  profile <<'P'
default browser firefox
theme set "Catppuccin Latte"
P
  doti '' omarchy apply; assert_ok
  assert_contains "$OUT" "Nothing chosen"
  assert_eq "" "$(om_log)" "accepting the picker as-is must run nothing"
  doti $'2\n\ny' omarchy apply; assert_ok
  assert_eq "theme set Catppuccin Latte" "$(om_log)"
}

test_omarchy_apply_dry_run() {
  om_setup
  profile <<<'default browser firefox'
  dotx omarchy apply -n --yes; assert_ok
  assert_contains "$OUT" "[dry] omarchy default browser firefox"
  assert_eq "" "$(om_log)"
}

test_omarchy_profile_is_never_evaluated() {
  om_setup
  # shellcheck disable=SC2016
  profile <<<'install $(touch $T/pwned) "two words" `touch $T/pwned2`'
  dotx omarchy apply --yes --all; assert_ok
  assert_no_file "$T/pwned"
  assert_no_file "$T/pwned2"
  # shellcheck disable=SC2016
  assert_eq 'install $(touch $T/pwned) two words `touch $T/pwned2`' "$(om_log)"
}

# ---------------------------------------------------------------- add / remove
test_omarchy_add_writes_profile_and_runs_nothing() {
  om_setup
  profile <<'P'
default browser chromium
theme set "Tokyo Night"
P
  dotx omarchy add default browser firefox --yes; assert_ok
  dotx omarchy add omarchy install dev-env node --yes; assert_ok
  dotx omarchy add theme set "Catppuccin Latte" --yes; assert_ok
  assert_eq $'default browser firefox\ntheme set "Catppuccin Latte"\ninstall dev-env node' "$(cat "$R/modules/omarchy/profile")"
  assert_contains "$OUT" "nothing was run"
  assert_eq "" "$(om_log)" "add must never run omarchy"
}

test_omarchy_add_interactive_from_catalog() {
  om_setup
  # kind 4 = install; catalog items: 1 dev-env node, 2 dev-env go, 3 tailscale, 4 voxtype
  doti $'4\n1 3\n\ny' omarchy add; assert_ok
  assert_eq $'install dev-env node\ninstall service tailscale' "$(cat "$R/modules/omarchy/profile")"
  assert_eq "" "$(om_log)"
}

test_omarchy_add_theme_with_spaces_then_apply() {
  om_setup
  doti $'2\n2\ny' omarchy add; assert_ok # kind 2 = theme, pick "Catppuccin Latte"
  assert_eq 'theme set "Catppuccin Latte"' "$(cat "$R/modules/omarchy/profile")"
  dotx omarchy apply --yes; assert_ok
  assert_eq "theme set Catppuccin Latte" "$(om_log)"
  assert_eq "Catppuccin Latte" "$(cat "$T/om/theme")"
}

test_omarchy_add_preinstalled_app_removal() {
  om_setup
  mkapp "$HOME/.local/share/applications" "Google Maps" webapp
  mkapp "$HOME/.local/share/applications" Docker tui
  doti $'6\n1 2\n\ny' omarchy add; assert_ok # kind 6 = drop-app
  assert_line "$R/modules/omarchy/profile" 'tui remove Docker'
  assert_line "$R/modules/omarchy/profile" 'webapp remove "Google Maps"'
}

test_omarchy_remove_lines() {
  om_setup
  profile <<'P'
default browser chromium
install dev-env node
theme set "Tokyo Night"
P
  dotx omarchy remove 2 --yes; assert_ok
  assert_eq $'default browser chromium\ntheme set "Tokyo Night"' "$(cat "$R/modules/omarchy/profile")"
  dotx omarchy remove nope --yes; assert_rc_fail "line numbers only"
  assert_eq "" "$(om_log)"
}

test_omarchy_catalog_expands_choices_and_skips_free_form() {
  om_setup
  load_libs
  assert_eq $'default browser chromium\ndefault browser firefox\ninstall dev-env node\ninstall dev-env go\ninstall service tailscale\ninstall dictation voxtype\nremove dev env node\nremove dev env go' \
    "$(om_catalog | cut -f1)"
}

# ---------------------------------------------------------------- profile library
test_profile_parsing_and_editing() {
  load_libs
  assert_eq "" "$(profile_strip '   # just a comment')"
  assert_eq 'theme set "A B"' "$(profile_strip '  omarchy theme set "A B"   # note')"
  assert_eq $'theme\nset\nA B' "$(profile_split 'theme set "A B"')"
  assert_eq 'webapp remove "Google Maps"' "$(profile_join webapp remove "Google Maps")"
  assert_eq "default browser" "$(profile_key 'default browser zen')"
  assert_eq "theme set" "$(profile_key 'theme set "A B"')"
  assert_eq "pkg add a" "$(profile_key 'pkg   add  a')"
  local f=$T/p
  printf '# head\ndefault browser chromium\npkg add a\n' >"$f"
  assert_eq $'# head\ndefault browser zen\npkg add a\ninstall dev-env go' \
    "$(profile_with_set "$f" 'default browser zen' 'install dev-env go' 'pkg add a' 'install dev-env go')"
  assert_eq $'# head\npkg add a' "$(profile_without "$f" 2)"
}

# ---------------------------------------------------------------- sync: omarchy
test_sync_records_changed_defaults_theme_and_font() {
  om_setup
  profile <<'P'
default browser chromium
theme set "Tokyo Night"
P
  echo firefox >"$T/om/default-browser"; echo "Catppuccin Latte" >"$T/om/theme"
  dotx sync --omarchy --yes; assert_ok
  assert_contains "$OUT" "-default browser chromium"
  assert_contains "$OUT" "+default browser firefox"
  assert_eq $'default browser firefox\ntheme set "Catppuccin Latte"\ndefault terminal ghostty\ndefault editor zed\nfont set "JetBrainsMono Nerd Font"' \
    "$(cat "$R/modules/omarchy/profile")"
  assert_eq "" "$(om_log)" "sync must not change the system"
  dotx sync --omarchy --yes; assert_ok
  assert_contains "$OUT" "Nothing to sync"
}

test_sync_records_user_packages_respecting_ignores() {
  om_setup
  mkmod gitmod <<<'PKGS=(git)'
  printf 'pkg nvidia*\n' >"$R/sync.ignore"
  printf 'git\nobsidian\nhtop\nyay-thing\nnvidia-utils\n' >"$T/om/pkgs"
  printf 'git\nobsidian\nhtop\nyay-thing\nnvidia-utils\n' >"$T/om/explicit"
  echo yay-thing >"$T/om/foreign"
  dotx sync --omarchy --yes; assert_ok
  local p=$R/modules/omarchy/profile
  assert_line "$p" "pkg add htop"
  assert_line "$p" "pkg aur add yay-thing"
  assert_line "$p" "pkg drop pinta"          # an Omarchy default that isn't installed
  assert_no_line "$p" "pkg add git"           # declared by a module
  assert_no_line "$p" "pkg add obsidian"      # an Omarchy default
  assert_no_line "$p" "pkg add nvidia-utils"  # ignored
  dotx sync --omarchy --yes; assert_contains "$OUT" "Nothing to sync"
}

test_sync_records_removed_preinstalled_apps() {
  om_setup
  mkapp "$OMARCHY_PATH/applications" HEY webapp
  mkapp "$OMARCHY_PATH/applications" Docker tui
  mkapp "$OMARCHY_PATH/applications" "Google Maps" webapp
  mkapp "$HOME/.local/share/applications" HEY webapp
  printf 'app Docker\n' >"$R/sync.ignore"
  dotx sync --omarchy --yes; assert_ok
  assert_line "$R/modules/omarchy/profile" 'webapp remove "Google Maps"'
  assert_no_line "$R/modules/omarchy/profile" 'tui remove Docker'
  assert_no_line "$R/modules/omarchy/profile" 'webapp remove HEY'
}

test_sync_needs_yes_without_terminal() {
  om_setup
  echo firefox >"$T/om/default-browser"
  dotx sync --omarchy; assert_rc_fail
  assert_eq "" "$(cat "$R/modules/omarchy/profile")"
}

# ---------------------------------------------------------------- sync: configs
test_sync_copies_local_config_edits_back_with_diff() {
  DOT_OMARCHY=0; export DOT_OMARCHY
  mkmod a <<<''
  mkhome a .config/foo/cfg v1
  dotx configs --copy --yes a; assert_ok
  echo v2 >"$HOME/.config/foo/cfg"
  dotx sync --configs --yes; assert_ok
  assert_contains "$OUT" "-v1"
  assert_contains "$OUT" "+v2"
  assert_eq v2 "$(cat "$R/modules/a/home/.config/foo/cfg")"
  dotx sync --configs --yes; assert_contains "$OUT" "Nothing to sync"
}

test_sync_ignores_linked_and_unmanaged_differences() {
  DOT_OMARCHY=0; export DOT_OMARCHY
  mkmod a <<<''
  mkhome a .config/foo/cfg v1
  mkdir -p "$HOME/.config/foo"; echo mine >"$HOME/.config/foo/cfg" # never installed by dot
  dotx sync --configs --yes; assert_ok
  assert_contains "$OUT" "Nothing to sync"
  assert_eq v1 "$(cat "$R/modules/a/home/.config/foo/cfg")"
}

test_sync_new_configs_are_opt_in() {
  DOT_OMARCHY=0; export DOT_OMARCHY
  mkdir -p "$HOME/.config/newapp"; echo x >"$HOME/.config/newapp/conf"
  dotx sync --configs --yes; assert_ok
  assert_contains "$OUT" "untracked config: ~/.config/newapp"
  assert_no_file "$R/modules/newapp"
  doti $'1\n\ny' sync --configs; assert_ok
  assert_file "$R/modules/newapp/module.sh"
  assert_eq x "$(cat "$R/modules/newapp/home/.config/newapp/conf")"
  assert_file "$HOME/.config/newapp/conf"  # stays in place, now a managed copy
  dotx sync --configs --yes; assert_contains "$OUT" "Nothing to sync"
}

test_sync_new_configs_customized_omarchy_and_size_limit() {
  om_setup
  mkdir -p "$OMARCHY_PATH/config/ghostty" "$OMARCHY_PATH/config/btop" "$HOME/.config/ghostty" "$HOME/.config/btop" "$HOME/.config/big"
  echo default >"$OMARCHY_PATH/config/ghostty/config"; echo mine >"$HOME/.config/ghostty/config"
  echo same >"$OMARCHY_PATH/config/btop/btop.conf"; echo same >"$HOME/.config/btop/btop.conf"
  head -c 20000 /dev/zero >"$HOME/.config/big/blob"
  SYNC_MAX_NEW_KB=8 dotx sync --configs --yes; assert_ok
  assert_contains "$OUT" "customized Omarchy config: ~/.config/ghostty → modules/omarchy"
  assert_contains "$OUT" "+mine"
  assert_not_contains "$OUT" "btop"   # identical to the Omarchy default
  assert_not_contains "$OUT" "big"    # too big: app data
}

# ---------------------------------------------------------------- configs remove
test_configs_remove_copies_and_links() {
  DOT_OMARCHY=0; export DOT_OMARCHY
  mkmod a <<<''
  mkhome a .config/foo/cfg
  mkhome a .zshrc
  dotx configs --copy --yes "$HOME/.config/foo"; assert_ok
  dotx configs --link --yes "$HOME/.zshrc"; assert_ok
  dotx configs --remove --yes a; assert_ok
  assert_no_file "$HOME/.config/foo"
  assert_no_file "$HOME/.zshrc"
  assert_file "$(echo "$HOME"/.local/state/dotfiles/backups/*/.config/foo/cfg)"
  assert_eq "" "$(cat "$HOME/.local/state/dotfiles/copies")"
}

test_configs_remove_leaves_unmanaged_files_alone() {
  DOT_OMARCHY=0; export DOT_OMARCHY
  mkmod a <<<''
  mkhome a .zshrc
  echo mine >"$HOME/.zshrc"
  dotx configs --remove --yes a; assert_ok
  assert_contains "$OUT" "Nothing to do"
  assert_eq mine "$(cat "$HOME/.zshrc")"
}

test_ui_pick_many_reports_cancel() {
  load_libs
  ui_choose_many() { return 1; }
  local -a got=(stale)
  ui_pick_many got "h" "" "a"$'\t'"x" && _fail "cancel must return 1"
  ui_choose_many() { printf 'a\nb\n'; }
  ui_pick_many got "h" "" "a"$'\t'"x" || _fail "should succeed"
  assert_eq "a b" "${got[*]}"
}

# ---------------------------------------------------------------- refresh (three-way copies)
test_refresh_updates_repo_changes_and_keeps_local_edits() {
  DOT_OMARCHY=0; export DOT_OMARCHY
  mkmod a <<<''
  mkhome a .config/clean/cfg v1
  mkhome a .config/edited/cfg v1
  mkhome a .config/both/cfg v1
  dotx configs --copy --all --yes; assert_ok
  mkhome a .config/clean/cfg v2   # repo changed (e.g. after git pull)
  mkhome a .config/both/cfg v2
  echo mine >"$HOME/.config/edited/cfg"
  echo mine >"$HOME/.config/both/cfg"
  dotx refresh; assert_ok
  assert_eq v2 "$(cat "$HOME/.config/clean/cfg")"
  assert_eq mine "$(cat "$HOME/.config/edited/cfg")" "local edit kept"
  assert_eq mine "$(cat "$HOME/.config/both/cfg")" "conflict kept"
  assert_contains "$OUT" "changed here and in the repo"
  dotx refresh; assert_contains "$OUT" "up to date"

  dotx sync --configs --yes; assert_ok   # local edits go to the repo; the conflict is opt-in
  assert_contains "$OUT" "changed here AND in the repo: ~/.config/both — check the diff (opt-in)"
  assert_eq mine "$(cat "$R/modules/a/home/.config/edited/cfg")"
  assert_eq v2 "$(cat "$R/modules/a/home/.config/both/cfg")" "--yes must not overwrite the repo side of a conflict"
  doti $'1\n\ny' sync --configs; assert_ok # pick the conflict explicitly
  assert_eq mine "$(cat "$R/modules/a/home/.config/both/cfg")"
  dotx sync --configs --yes; assert_contains "$OUT" "Nothing to sync"
}

test_tree_hash_tracks_content() {
  load_libs
  mkdir -p "$T/d/sub"; echo a >"$T/d/sub/f"
  local h1; h1=$(tree_hash "$T/d")
  assert_eq 40 "${#h1}"
  echo b >"$T/d/sub/f"
  [[ $(tree_hash "$T/d") != "$h1" ]] || _fail "hash must change with content"
  echo a >"$T/d/sub/f"
  assert_eq "$h1" "$(tree_hash "$T/d")"
}

test_sync_can_ignore_unpicked_changes() {
  om_setup
  printf 'git\nobsidian\npinta\nhtop\nbtm\n' >"$T/om/pkgs"
  printf 'htop\nbtm\n' >"$T/om/explicit"
  mkdir -p "$HOME/.config/junk"; echo x >"$HOME/.config/junk/f"
  # changes: 1-5 current defaults/theme/font (empty profile), 6 htop, 7 btm,
  # 8 new config junk (opt-in). Untick 7, accept, ignore the rest: yes, save: yes
  doti $'7\n\ny\ny' sync; assert_ok
  assert_line "$R/modules/omarchy/profile" "pkg add htop"
  assert_line "$R/sync.ignore" "pkg btm"
  assert_line "$R/sync.ignore" "config junk"
  dotx sync --yes; assert_ok
  assert_contains "$OUT" "Nothing to sync"
}
