# dotfiles

My configs and apps, managed by [dot](https://github.com/PatrykGodlewski/dot).

## Set up a machine

```bash
curl -fsSL https://raw.githubusercontent.com/PatrykGodlewski/dot/main/install.sh | bash -s -- --repo https://github.com/PatrykGodlewski/dotfiles --dir ~/Projects/dotfiles
```

This installs dot, clones this repo to `~/Projects/dotfiles` and starts `dot setup`, which asks:
1. **copy or link**: how configs go on this machine
2. **apps**: which modules to install (each comes with its configs)
3. **more configs**: configs to add without installing their apps
4. **Omarchy profile** (on Omarchy): which defaults / installers / removals to run

Pick nothing to skip a step. Nothing changes without a confirmation.

Later: `dot` (menu), `dot sync` (record what changed on this machine), `dot update` (pull + refresh).

## What's here

- `modules/<name>/module.sh`: what to install; `modules/<name>/home/`: files that mirror `$HOME`
- `presets/`: `minimal` (shell + editor), `headless` (+ dev tools), `desktop` (+ Hyprland desktop)
- `modules/omarchy/profile`: my Omarchy defaults, theme, installers and removed preinstalls
- `sync.ignore`: what `dot sync` should never propose (on top of dot's built-in list)

Notes:
- On Omarchy, `hyprland` is skipped: Omarchy manages its own Hyprland setup.
- `bash` loads Omarchy's own shell setup first when it runs on Omarchy, and only switches to zsh elsewhere.

Check the repo with `dot check`.
