# upgrade-check checkers

Each executable file here is one upgrade source. Run in filename order.

- **Output:** one line per upgradable thing: `name current latest`
  (whitespace-separated). Print nothing when up to date.
- **Header comments (optional):**
  - `# label: <text>`: how the source is shown (default: file name without the `NN-` prefix)
  - `# update: <command>`: what the Update button runs for it. Identical commands
    run once, so everything covered by `omarchy update` shares `omarchy-update`.
- Each checker gets 90 s; a failing or timed-out checker is skipped.

Machine-local checkers go in `~/.config/upgrade-check/checkers/`. A file there
with the same name as one here overrides it; make it non-executable
(`chmod -x`) to turn a checker off.

Example: `~/.config/upgrade-check/checkers/50-npm`
```bash
#!/bin/bash
# label:  npm -g
# update: npm update -g
npm outdated -g --parseable 2>/dev/null | awk -F: '{ split($2,w,"@"); split($4,c,"@"); print c[1], c[2], w[2] }'
```
