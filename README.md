# dotfiles

My configs and apps, managed by [dot](https://github.com/PatrykGodlewski/dot).

```bash
curl -fsSL https://raw.githubusercontent.com/PatrykGodlewski/dot/main/install.sh | bash
git clone https://github.com/PatrykGodlewski/dotfiles ~/Projects/dotfiles   # dot finds it there
dot configs      # copy / link the configs I want on this machine
dot              # everything else: presets, modules, Omarchy, sync
```

## What's here

- `modules/<name>/module.sh`: what to install; `modules/<name>/home/`: files that mirror `$HOME`
- `presets/`: `minimal` (shell + editor), `headless` (+ dev tools), `desktop` (+ Hyprland desktop)
- `modules/omarchy/profile`: my Omarchy defaults, theme, installers and removed preinstalls
- `sync.ignore`: what `dot sync` should never propose (on top of dot's built-in list)

Notes:
- On Omarchy, `hyprland` is skipped: Omarchy manages its own Hyprland setup.
- The `bash` module replaces `~/.bashrc`. Omarchy's own `.bashrc` loads Omarchy's environment and defaults, so don't link it there.

Check the repo with `dot check`.
