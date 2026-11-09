# dotfiles

My configs and tools, managed by **`dot`**, a small interactive bash CLI.
It installs packages and links configs on **Arch-based** distros (Arch, EndeavourOS, Manjaro…) and **Debian/Ubuntu-based** ones (incl. WSL).

## Install

```bash
git clone https://github.com/PatrykGodlewski/dotfiles ~/Projects/dotfiles
~/Projects/dotfiles/install.sh
# or, once the clone exists:
curl -fsSL https://raw.githubusercontent.com/PatrykGodlewski/dotfiles/main/install.sh | bash
```

The installer only installs the `dot` command. It links `~/.local/bin/dot` to your clone (the one it runs from, else `$DOTFILES_DIR`, `~/Projects/dotfiles` or `~/projects/dotfiles`) and puts `~/.local/bin` at the **front** of PATH in `~/.bashrc` / `~/.zshrc`, because graphviz ships its own `/usr/bin/dot`.
It doesn't clone, pull, install packages or touch configs. Then:

```bash
dot configs    # copy / link the configs you pick (no packages)
dot            # menu: presets, modules, Omarchy, sync, …
```

Without gum, `dot` uses plain prompts; `dot apply core` installs gum and base tools.

## Copying configs to this machine

```bash
dot configs                 # choose copy / link / remove, then tick the configs
dot configs --copy          # real copies
dot configs --link          # symlinks into the repo; `git pull` updates them
dot configs --remove        # take configs dot put here away again (backed up first)
dot configs --copy kitty ~/.config/nvim --yes   # non-interactive: modules or paths
dot configs -n --copy --all # dry run over everything
```

Configs that are already up to date aren't listed. Anything that gets replaced is moved to `~/.local/state/dotfiles/backups/<time>/`, never deleted.
`dot configs` never installs packages and doesn't change which modules are selected on this machine.

dot remembers each copy and a hash of its content, so it knows which side changed:

| What changed | What happens |
|---|---|
| the repo (e.g. after `git pull`) | `dot refresh` / `dot update` re-copies it |
| the file on this machine | `dot sync` shows the diff and offers to write it back to the repo |
| both | nothing is overwritten; `dot sync` shows the diff and lets you pick a side |

## Syncing changes back into the repo

Installed an app or changed a default through the Omarchy menu? Edited a config? Run:

```bash
dot sync              # everything; shows every diff, then a picker
dot sync --omarchy    # only defaults / theme / font / packages / apps
dot sync --configs    # only configs
```

It finds:
- Omarchy defaults, theme and font that differ from the profile
- packages you installed that aren't Omarchy defaults (compared with `omarchy-pkg-defaults`) and Omarchy defaults you removed
- preinstalled web apps / TUIs you removed
- copied configs you edited, and **opt-in**: Omarchy configs you customized, small untracked configs, conflicts

Sync only writes to the repo, never to the system. Things you don't pick can be added to `sync.ignore` so they stop coming back. Hardware and base-system packages are ignored by default.

## Omarchy

`modules/omarchy/profile` is a list of plain `omarchy` commands. Omarchy does all the real work; dot just keeps the list and checks which lines are already in effect.

```
default browser chromium
theme set "Tokyo Night"
install dev-env node
webapp remove HEY
pkg drop obsidian
```

```bash
dot omarchy            # menu
dot omarchy status     # = in effect   + not yet   ~ can't be checked
dot omarchy add        # pick from Omarchy's own catalog (`omarchy commands`): defaults,
                       #   themes, fonts, installers, removers, preinstalls — nothing runs
dot omarchy apply      # pick lines to run; nothing is preselected, you confirm first
dot omarchy remove     # delete lines (doesn't undo them on the system)
dot omarchy sync       # = dot sync --omarchy
```

Profile lines are never evaluated as shell: `$(…)` stays literal text. `DOT_OMARCHY=0` turns the integration off.

## Everyday use

```bash
dot                 # interactive menu
dot configs         # pick configs to copy / link / remove (no packages)
dot sync            # record changes made on this machine into the repo (shows diffs)
dot omarchy         # Omarchy defaults / theme / installers / preinstalls
dot status          # what's selected / installed / linked
dot plan            # dry run: every package, link, backup and script that would run
dot plan -v neovim  #   …including the code of custom setup() steps
dot preset desktop  # start the picker from a preset, adjust, apply
dot select          # change which modules this machine has
dot apply           # (re)apply this machine's selection — safe to run repeatedly
dot apply tmux zsh  # add specific modules (dependencies come along)
dot remove discord  # unlink + deselect, then offer to uninstall its packages
dot prune           # uninstall packages dot installed that nothing needs anymore
dot update          # git pull, refresh copied configs, re-apply the selection
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
dot                 entry point: flags, help, command dispatch
cmd/                one file per command group (defines cmd_*)
lib/                reusable logic: os, ui, managers, state, links, modules,
                    profile (Omarchy profile file), omarchy (adapters), sync
install.sh          installs the `dot` command (link + PATH), nothing else
managers/           package managers: pacman apt aur cargo flatpak services
modules/<name>/
  module.sh         what to install (packages + optional hooks)
  home/             files that mirror $HOME and get copied / linked
modules/omarchy/profile   Omarchy commands (see above)
presets/            module lists; "@other" includes another preset
sync.ignore         what `dot sync` never proposes
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
- `~/.local/state/dotfiles/copies`: configs dot copied here, with a content hash
- `~/.local/state/dotfiles/installed`: packages that **dot** installed. `prune` and `remove` only ever uninstall these, never packages that were already on the system.

### New package manager

Add `managers/<name>.sh` defining `M_DESC`, `M_VAR` (the module variable, e.g. `NPM`), optionally `M_FAMILY`, and the functions `m_available`, `m_ensure`, `m_has`, `m_install`, `m_remove`. See `managers/flatpak.sh`.

## Tests

```bash
tests/run.sh            # ~100 fast tests, no dependencies, never touch your system
tests/run.sh prune      # only tests with "prune" in the name
tests/run.sh --docker   # + full bootstrap in fresh Ubuntu and Arch containers
```

Each test gets a throwaway `$HOME` and a copy of `dot` with **fake package managers** and a stateful fake `omarchy`.
Every command that could change the real system (`omarchy`, `sudo`, `pacman`, `yay`, `apt`, `systemctl`, `curl`, …) resolves to a trap. If a test reaches one, the call is logged and the test fails. Installs are recorded in a file, and a fake `/etc/os-release` lets the tests act as Arch or Ubuntu.
What's covered:
- **Unit:** OS detection, the linking rules, presets and dependency resolution
- **CLI:** apply, plan, dry-run, remove, prune, adopt, new, status, configs, refresh
- **Omarchy + sync:** profile parsing (never evaluated), status/apply/add/remove, catalog parsing, recording defaults / packages / apps, config write-back, conflicts, ignores
- **Interactive flows:** pickers and confirmations driven through plain prompts (`DOT_FORCE_TTY=1`)
- **Repo integrity:** every module loads on both distros, presets reference real modules, managers implement the interface, no two modules link the same path

Write new tests in `tests/test_*.sh` as `test_<name>()` functions. The helpers (`mkmod`, `mkhome`, `dotx`, `assert_*`) are in `tests/lib.sh`.
