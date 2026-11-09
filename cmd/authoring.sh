# shellcheck shell=bash
# Repo authoring: new, adopt, edit.

new_module() { # new_module name desc pkgs pacman apt  -> creates files
  local name=$1 desc=$2 pkgs=$3 pac=$4 apt=$5
  local dir="$DOT_ROOT/modules/$name"
  [[ -e $dir/module.sh ]] && die "module '$name' already exists"
  run mkdir -p "$dir/home" || return 1
  [[ $DOT_DRY == 1 ]] && return 0
  sed -e "s|__NAME__|$name|g" -e "s|__DESC__|${desc//|/ }|g" -e "s|__PKGS__|$pkgs|" \
    -e "s|__PACMAN__|$pac|" -e "s|__APT__|$apt|" "$DOT_HOME/templates/module.sh" >"$dir/module.sh"
  touch "$dir/home/.gitkeep"
  ok "created $(pretty "$dir/module.sh")"
}

cmd_new() {
  local name=${1:-} desc='' pkgs='' pac='' apt='' configs=''
  if ui_interactive && [[ $DOT_YES != 1 ]]; then
    [[ -n $name ]] || name=$(ui_input "Module name (e.g. starship)")
    [[ -n $name ]] || return 1
    desc=$(ui_input "One-line description")
    pkgs=$(ui_input "Packages with the same name on Arch & Ubuntu (space separated, optional)")
    pac=$(ui_input "Arch-only packages (optional)")
    apt=$(ui_input "Ubuntu-only packages (optional)")
    configs=$(ui_input "Existing configs to adopt, e.g. ~/.config/$name (optional)")
  fi
  [[ -n $name && $name =~ ^[a-zA-Z0-9_-]+$ ]] || die "usage: dot new <name> (letters, digits, - _)"
  new_module "$name" "${desc:-$name}" "$pkgs" "$pac" "$apt" || return 1
  local c
  for c in $configs; do cmd_adopt "${c/#\~/$HOME}" "$name"; done
  if ui_interactive && [[ $DOT_YES != 1 ]]; then
    local presets=() items=() n
    for n in $(preset_all); do items+=("$n"$'\t'"$(preset_desc "$n")"); done
    ui_pick_many presets "Add '$name' to presets? (optional)" "" "${items[@]}" || presets=()
    for n in "${presets[@]}"; do
      [[ -n $n ]] && echo "$name" >>"$DOT_ROOT/presets/$n" && ok "added to preset $n"
    done
    if ui_confirm "Open module.sh in ${EDITOR:-vi}?"; then "${EDITOR:-vi}" "$DOT_ROOT/modules/$name/module.sh"; fi
  fi
  info "next: dot plan $name   →   dot apply $name"
}

cmd_adopt() {
  local path=${1:-} mod=${2:-}
  [[ -n $path ]] || die "usage: dot adopt <path> [module]"
  path=$(realpath -s "$path")
  [[ $path == "$HOME"/* ]] || die "only paths inside \$HOME can be adopted"
  [[ -e $path || -L $path ]] || die "$(pretty "$path") does not exist"
  local rel=${path#"$HOME"/} unit
  unit=$(link_unit "$rel")
  if [[ $unit != "$rel" ]]; then
    warn "dot links whole entries: will adopt $(pretty "$HOME/$unit") instead of $(pretty "$path")"
    ui_confirm "Continue?" || return 1
  fi
  if [[ -L $HOME/$unit ]]; then
    die "$(pretty "$HOME/$unit") is already a symlink ($(readlink "$HOME/$unit"))"
  fi
  if [[ -z $mod ]]; then
    local -a items=("+new"$'\t'"create a new module")
    local n
    for n in $(mod_all); do mod_load "$n"; items+=("$n"$'\t'"$DESC"); done
    mod=$(ui_choose_one "Adopt $(pretty "$HOME/$unit") into which module?" "${items[@]}") || return 1
    if [[ $mod == +new ]]; then
      mod=$(ui_input "New module name" "$(basename "$unit" | sed 's/^\.//')")
    fi
  fi
  mod_exists "$mod" || new_module "$mod" "$mod" "" "" "" || return 1
  local dest="$DOT_ROOT/modules/$mod/home/$unit"
  [[ -e $dest ]] && die "$(pretty "$dest") already exists in the repo"
  run mkdir -p "$(dirname "$dest")" &&
    run mv "$HOME/$unit" "$dest" &&
    run ln -s "$dest" "$HOME/$unit" || die "adopt failed"
  rm -f "$DOT_ROOT/modules/$mod/home/.gitkeep"
  sel_add "$mod"
  ok "adopted $(pretty "$HOME/$unit") → modules/$mod/home/$unit (now a symlink)"
  info "commit it: git -C $(pretty "$DOT_ROOT") add modules/$mod"
}

cmd_edit() {
  local mod=${1:-}
  if [[ -z $mod ]]; then
    local -a items=() n
    for n in $(mod_all); do mod_load "$n"; items+=("$n"$'\t'"$DESC"); done
    mod=$(ui_choose_one "Edit which module?" "${items[@]}") || return 1
  fi
  mod_exists "$mod" || die "unknown module: $mod"
  "${EDITOR:-vi}" "$DOT_ROOT/modules/$mod/module.sh"
}
