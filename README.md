# dotfiles

My configs and apps, managed by [dot](https://github.com/PatrykGodlewski/dot).

## Set up a machine

```bash
curl -fsSL https://raw.githubusercontent.com/PatrykGodlewski/dot/main/install.sh | bash -s -- --repo https://github.com/PatrykGodlewski/dotfiles --dir ~/projects/dotfiles --projects ~/projects
```

This installs dot, clones this repo to `~/projects/dotfiles`, sets the projects folder to `~/projects` and starts `dot setup`, which asks:
1. **projects folder**: confirm or change it (saved as `$DOTS_PROJECT_ROOT`)
2. **copy or link**: how configs go on this machine
3. **apps**: which modules to install (each comes with its configs)
4. **more configs**: configs to add without installing their apps
5. **Omarchy profile** (on Omarchy): which defaults / installers / removals to run

Pick nothing to skip a step. Nothing changes without a confirmation.

Later: `dot projects <path>` (move the projects folder), `dot` (menu), `dot sync` (record what changed on this machine), `dot update` (pull + refresh).

## What's here

- `modules/<name>/module.sh`: what to install; `modules/<name>/home/`: files that mirror `$HOME`
- `presets/`: `minimal` (git, shell, tmux, neovim), `headless` (+ dev tools), `desktop` (+ Hyprland desktop)
- `modules/omarchy/profile`: my Omarchy defaults, theme, installers and removed preinstalls
- `sync.ignore`: what `dot sync` should never propose (on top of dot's built-in list)

Notes:
- On Omarchy, `hyprland` is skipped: Omarchy manages its own Hyprland setup.
- `shell` sets up bash and zsh the same way on every distro and makes zsh the login shell (log out and in once afterwards):
  - `~/.config/shell/env.sh`, `aliases.sh`, `functions.sh`: shared by both shells. Edit these for PATH, aliases and functions.
  - `env.sh` also loads `~/.config/dotfiles/env.sh` (written by `dot`), which exports `DOTS_PROJECT_ROOT`
- Scripts that need the projects folder read `$DOTS_PROJECT_ROOT` instead of a hardcoded path (e.g. `tmux-sessionizer`). Change it with `dot projects <path>`.
  - `~/.bashrc`: the distro's own default `.bashrc` (Omarchy's setup on Omarchy), then the shared files
  - `~/.zshrc`: Omarchy's setup (on Omarchy), the shared files, zinit plugins, oh-my-posh prompt

Check the repo with `dot check`.
