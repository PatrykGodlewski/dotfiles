# upgrade-check checkers

Each executable file here is one upgrade source. They run in file-name order,
which is also the order they appear in the notification.

- **Output:** one line per upgradable thing, `name current latest`
  (whitespace-separated). Print nothing when everything is up to date.
- **Header comments (optional):**
  - `# label: <text>` is how the source is shown (default: file name without the `NN-` prefix).
  - `# update: <command>` is what the Update button runs for it. Each distinct
    command runs once, so everything `omarchy update` covers shares `omarchy-update`.
- Each checker gets 90 s. A failing or timed-out checker is skipped.
- `*.md` files are ignored.

Machine-local checkers go in `~/.config/upgrade-check/checkers/`. A file there
with the same name as one here overrides it. Make it non-executable
(`chmod -x`) to turn a checker off.

Check your work with `upgrade-check checkers`, then `upgrade-check check && upgrade-check list`.

Example: `~/.config/upgrade-check/checkers/50-npm`
```bash
#!/bin/bash
# label: npm -g
# update: npm update -g
npm outdated -g --json 2>/dev/null |
  jq -r 'to_entries[] | "\(.key) \(.value.current) \(.value.latest)"'
```
