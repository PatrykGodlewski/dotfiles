# shellcheck shell=bash
# Integrity checks on the REAL repo contents (modules, presets, managers).

_real_modules() { for d in "$REPO"/modules/*/; do basename "$d"; done; }

test_repo_all_scripts_parse() {
  local f bad=''
  for f in "$REPO"/dot "$REPO"/install.sh "$REPO"/lib/*.sh "$REPO"/managers/*.sh \
    "$REPO"/modules/*/module.sh "$REPO"/templates/module.sh; do
    bash -n "$f" 2>/dev/null || bad+=" $f"
  done
  assert_eq "" "$bad" "syntax errors in:"
}

test_repo_modules_load_on_every_os() {
  local os m
  for os in arch ubuntu; do
    use_os "$os"
    DOT_ROOT=$REPO DOT_HOME=$REPO
    (
      export DOT_ROOT=$REPO DOT_HOME=$REPO
      for f in core os ui managers state links modules github; do source "$REPO/lib/$f.sh"; done
      detect_os; managers_load
      for m in $(_real_modules); do
        [[ -f $REPO/modules/$m/module.sh ]] || _fail "modules/$m has no module.sh"
        out=$(mod_load "$m" 2>&1) || _fail "$m fails to load on $os: $out"
        [[ -z $out ]] || _fail "$m prints while loading on $os: $out"
        mod_load "$m"
        [[ -n $DESC ]] || _fail "$m has no DESC"
        for d in "${DEPENDS[@]}"; do mod_exists "$d" || _fail "$m depends on missing module $d"; done
      done
    ) || exit 1
  done
}

test_repo_presets_reference_existing_modules() {
  local p m
  for p in "$REPO"/presets/*; do
    [[ $(head -n1 "$p") == '#'* ]] || _fail "$(basename "$p") needs a '# description' first line"
    while read -r m; do
      m=${m%%#*}; m=${m//[[:space:]]/}
      [[ -z $m ]] && continue
      if [[ $m == @* ]]; then
        [[ -f $REPO/presets/${m#@} ]] || _fail "preset $(basename "$p") includes missing @${m#@}"
      else
        [[ -f $REPO/modules/$m/module.sh ]] || _fail "preset $(basename "$p") lists missing module $m"
      fi
    done <"$p"
  done
}

test_repo_managers_implement_interface() {
  local f fn
  for f in "$REPO"/managers/*.sh; do
    (
      source "$f"
      [[ -n ${M_VAR:-} ]] || _fail "$(basename "$f"): M_VAR missing"
      [[ -n ${M_DESC:-} ]] || _fail "$(basename "$f"): M_DESC missing"
      for fn in m_available m_ensure m_has m_install m_remove; do
        [[ $(type -t $fn) == function ]] || _fail "$(basename "$f"): $fn missing"
      done
    ) || exit 1
  done
}

test_repo_no_conflicting_link_targets() {
  # two modules must never link the same path in $HOME
  load_libs
  DOT_ROOT=$REPO DOT_HOME=$REPO
  local m dupes
  dupes=$(for m in $(_real_modules); do links_of "$m" | cut -f2; done | sort | uniq -d)
  assert_eq "" "$dupes" "linked by more than one module:"
}

test_repo_core_is_required() {
  ( source "$REPO/modules/core/module.sh"; [[ ${REQUIRED:-0} == 1 ]] ) || _fail "core must be REQUIRED=1"
}

test_repo_install_sh_wrapped_in_main() {
  # protects against running a half-downloaded script via curl | bash
  assert_eq 'main "$@"' "$(grep -v '^\s*$' "$REPO/install.sh" | tail -n1)"
}

test_repo_template_has_placeholders() {
  local t; t=$(cat "$REPO/templates/module.sh")
  for p in __NAME__ __DESC__ __PKGS__ __PACMAN__ __APT__; do assert_contains "$t" "$p"; done
}
