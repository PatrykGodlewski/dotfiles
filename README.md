# dotfiles

My configs and tools, managed by **`dot`**, a small interactive bash CLI.
It installs packages and links configs on **Arch-based** distros (Arch, EndeavourOS, Manjaro…) and **Debian/Ubuntu-based** ones (incl. WSL).

## Install (new or existing machine)

```bash
curl -fsSL https://raw.githubusercontent.com/PatrykGodlewski/dotfiles/main/install.sh | bash
```

It installs git + curl if they're missing, clones the repo to `~/Projects/dotfiles` (or reuses an existing clone there or in `~/projects/dotfiles`), and links `dot` into `~/.local/bin`.
It also puts `~/.local/bin` at the **front** of PATH in `~/.bashrc` / `~/.zshrc`, because graphviz ships its own `/usr/bin/dot`.
Then it asks what to do:

| Mode | What happens |
|---|---|
| `configs` (default) | pick which configs to **copy** or **link** into `$HOME`; no packages are installed |
| `full` | install the `core` module (gum, build tools), then open the `dot` menu |
| `none` | only install the `dot` command |

Skip the question with `curl … | bash -s -- configs` (or `full` / `none`).
Overrides: `DOTFILES_DIR=… DOTFILES_BRANCH=… DOT_NO_MENU=1 bash install.sh`. In shells that were already open, run `exec $SHELL -l` afterwards.

## Copying configs to this machine

```bash
dot configs                 # choose copy or link, then tick the configs you want
dot configs --copy          # real copies; run again later to update the changed ones
dot configs --link          # symlinks into the repo; `git pull` updates them
dot configs --copy kitty ~/.config/nvim --yes   # non-interactive: modules or paths
dot configs -n --copy --all # dry run over everything
```

Configs that are already up to date aren't listed. Anything already at a target is moved to `~/.local/state/dotfiles/backups/<time>/`, never deleted.
`dot configs` never installs packages and doesn't change which modules are selected on this machine.

## Everyday use

```bash
dot                 # interactive menu
dot configs         # pick configs to copy / link (no packages)
dot status          # what's selected / installed / linked
dot plan            # dry run: every package, link, backup and script that would run
dot plan -v neovim  #   …including the code of custom setup() steps
dot preset desktop  # start the picker from a preset, adjust, apply
dot select          # change which modules this machine has
dot apply           # (re)apply this machine's selection — safe to run repeatedly
dot apply tmux zsh  # add specific modules (dependencies come along)
dot remove discord  # unlink + deselect, then offer to uninstall its packages
dot prune           # uninstall packages dot installed that nothing needs anymore
dot update          # git pull + apply
dot doctor
```

Global flags: `-n/--dry-run` (only print commands), `-y/--yes` (no prompts), `-v/--verbose`.

`dot plan` legend: `+` install/link · `=` already done · `!` existing file gets backed up · `~` skipped on this OS.

## Adding things

**New tool:**
```bash
dot new starship              # asks: description, packages, configs to adopt, presets
dot edit starship             # tweak modules/starship/module.sh
dot plan starship && dot apply starship
```

**Existing config on this machine:**
```bash
dot adopt ~/.config/starship  # moves it into a module and links it back
git add modules/starship && git commit
```

## How it works

```
dot                 the CLI
install.sh          fresh-machine bootstrap (the curl one-liner)
lib/                CLI internals
managers/           package managers: pacman apt aur cargo flatpak services
modules/<name>/
  module.sh         what to install (packages + optional hooks)
  home/             files that mirror $HOME and get symlinked
presets/            module lists; "@other" includes another preset
templates/          what `dot new` copies
tests/              test suite (tests/run.sh)
```

### A module

```bash
# modules/lazygit/module.sh
DESC="lazygit terminal UI + config"
PACMAN=(lazygit)                        # Arch: from the repos

is_installed() { has lazygit; }         # so setup() only runs when needed
setup() {                               # Ubuntu: latest GitHub release binary
  gh_install_bin jesseduffield/lazygit "linux_$(goarch)\.tar\.gz$" lazygit
}
```

| Variable | Meaning |
|---|---|
| `DESC` | one-line description shown in menus |
| `PKGS` | same package name everywhere → pacman on Arch, apt on Ubuntu |
| `PACMAN` `APT` `AUR` `CARGO` `FLATPAK` | per-manager packages (AUR bootstraps `yay`, cargo bootstraps rustup) |
| `SERVICES` | systemd units to `enable --now` (skipped where there's no systemd, e.g. WSL) |
| `DEPENDS` | modules applied first |
| `ONLY_ON` / `SKIP_ON` | OS tags: `arch` `debian` `ubuntu` `endeavouros` … `wsl` |
| `REQUIRED=1` | always applied (only `core`) |

| Hook | When |
|---|---|
| `is_installed` | returns 0 if the custom part is done (`setup` is skipped) |
| `setup` | custom install: `run`, `run_sh '…'`, `as_root`, `gh_install_bin`, `gh_install_tree` |
| `configure` | after linking, on every apply; must be idempotent |
| `teardown` | on `dot remove` |

`module.sh` is plain bash, so you can branch on `$OS_FAMILY` (`arch`/`debian`), `$OS_ID` or `$OS_WSL`. The `discord` module does that to use flatpak outside Arch.

### Linking rules

Everything under `modules/<m>/home/` is symlinked into `$HOME` at the first level below `~`, `~/.config`, `~/.local`, `~/.local/share` or `~/.local/bin`.
For example, `home/.config/nvim/` becomes the link `~/.config/nvim`. Edits made through the link land straight in the repo, so `git diff` shows them.
An existing file at the target is moved to `~/.local/state/dotfiles/backups/<time>/`, never deleted.

### Machine state (not in git)

- `~/.config/dotfiles/selected`: modules chosen on this machine
- `~/.config/dotfiles/secrets.env`: API keys (from `modules/secrets`, sourced by zsh)
- `~/.local/state/dotfiles/installed`: packages that **dot** installed. `prune` and `remove` only ever uninstall these, never packages that were already on the system.

### New package manager

Add `managers/<name>.sh` defining `M_DESC`, `M_VAR` (the module variable, e.g. `NPM`), optionally `M_FAMILY`, and the functions `m_available`, `m_ensure`, `m_has`, `m_install`, `m_remove`. See `managers/flatpak.sh`.

## Tests

```bash
tests/run.sh            # ~60 fast tests, no dependencies, never touch your system
tests/run.sh prune      # only tests with "prune" in the name
tests/run.sh --docker   # + full bootstrap in fresh Ubuntu and Arch containers
```

Each test gets a throwaway `$HOME` and a copy of `dot` with **fake package managers**. Installs are recorded in a file, and a fake `/etc/os-release` lets the tests act as Arch or Ubuntu.
What's covered:
- **Unit:** OS detection, the linking rules, presets and dependency resolution
- **CLI:** apply, plan, dry-run, remove, prune, adopt, new, status, configs
- **Repo integrity:** every module loads on both distros, presets reference real modules, managers implement the interface, no two modules link the same path

Write new tests in `tests/test_*.sh` as `test_<name>()` functions. The helpers (`mkmod`, `mkhome`, `dotx`, `assert_*`) are in `tests/lib.sh`.
