#!/bin/bash
# Regression tests for upgrade-check. Fully isolated: temporary XDG dirs and
# stubbed desktop commands, so it never touches real state or notifications.
#   bash modules/upgrades/test.sh
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TOOL="$HERE/home/.local/bin/upgrade-check"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

export XDG_DATA_HOME=$T/data XDG_CONFIG_HOME=$T/config XDG_STATE_HOME=$T/state
SHARED=$XDG_DATA_HOME/upgrade-check/checkers
LOCAL=$XDG_CONFIG_HOME/upgrade-check/checkers
CALLS=$T/calls
mkdir -p "$SHARED" "$LOCAL" "$T/bin"

# Desktop stubs record their calls instead of acting.
for stub in omarchy-shell omarchy-notification-send omarchy-launch-floating-terminal-with-presentation; do
  printf '#!/bin/bash\necho "%s $*" >>"%s"\n' "$stub" "$CALLS" >"$T/bin/$stub"
done
chmod +x "$T/bin"/*
export PATH="$T/bin:$PATH"

pass=0 fail=0
ok() { if eval "$2"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1"; fi; }
checker() { # checker <path> <body> [mode]
  printf '#!/bin/bash\n%s\n' "$2" >"$1"
  chmod "${3:-+x}" "$1"
}
status() { "$TOOL" status | jq -r "$1"; }
toasts() { grep -c "omarchy-notification-send" "$CALLS" || true; }
: >"$CALLS"

# --- checkers: order, overrides, disabling, failures
checker "$SHARED/10-fake" $'# label: Fake\n# update: echo update-fake\necho "a 1.0 1.1"\necho\necho "<b>x 2 3"'
checker "$SHARED/20-off" 'echo "hidden 1 2"'
checker "$LOCAL/20-off" 'echo "hidden 1 2"' -x
checker "$LOCAL/30-local" $'# update: echo update-local\necho "tool 0.1 0.2"'
checker "$LOCAL/40-broken" 'exit 3'
echo "notes" >"$SHARED/README.md"

ok "lists active checkers in order" '[[ $("$TOOL" checkers | awk "{print \$1}" | paste -sd,) == 10-fake,30-local,40-broken ]]'

"$TOOL" check
ok "collects items, skipping disabled and broken" '[[ $(status .count) == 3 ]]'
ok "uses label header, falls back to id" '[[ $(status ".lines | join(\"|\")") == "Fake: a, <b>x|local: tool" ]]'
ok "markup-like names stay data" '"$TOOL" list | grep -q "<b>x"'
ok "plain check does not toast" '[[ $(toasts) == 0 ]]'
ok "check refreshes the widget" 'grep -q "omarchy-shell -q local.upgrades refresh" "$CALLS"'

# --- notifications: once per set, dismiss until the set changes
"$TOOL" check --notify
"$TOOL" check --notify
ok "toasts a new set exactly once" '[[ $(toasts) == 1 ]]'

"$TOOL" dismiss
ok "dismiss hides the widget" '[[ $(status .dismissed) == true ]]'
"$TOOL" check --notify
ok "same set stays dismissed, no toast" '[[ $(status .dismissed) == true && $(toasts) == 1 ]]'

echo 'echo "b 1 2"' >>"$SHARED/10-fake"
"$TOOL" check --notify
ok "a changed set un-dismisses and toasts" '[[ $(status .dismissed) == false && $(toasts) == 2 ]]'

"$TOOL" notify
ok "notify re-shows on demand" '[[ $(toasts) == 3 ]]'
ok "toast actions use the tool path" 'grep -q -- "--action Update $TOOL update" "$CALLS"'

# --- max-age throttling
before=$(status .checked)
echo 'echo "c 1 2"' >>"$SHARED/10-fake"
"$TOOL" check --max-age 3600
ok "--max-age skips a fresh check" '[[ $(status .count) == 4 && $(status .checked) == "$before" ]]'
"$TOOL" check --max-age 0
ok "--max-age 0 always checks" '[[ $(status .count) == 5 ]]'

# --- updates: each distinct command once
out=$("$TOOL" run-updates 2>&1)
ok "runs each update command once" '[[ $(grep -c "^update-fake$" <<<"$out") == 1 && $(grep -c "^update-local$" <<<"$out") == 1 ]]'

# --- empty state
rm "$SHARED/10-fake" "$LOCAL/30-local"
"$TOOL" check
ok "empty set reports up to date" '[[ $(status .count) == 0 && $("$TOOL" list) == "Everything is up to date" ]]'

# --- built-in checkers parse their tools' output
BUILTIN="$HERE/home/.local/share/upgrade-check/checkers"
stub() { printf '#!/bin/bash\n%s\n' "$2" >"$T/bin/$1"; chmod +x "$T/bin/$1"; }
stub omarchy-update-available 'echo "Omarchy is up to date"; exit 1'
ok "omarchy: up to date prints nothing" '[[ -z $("$BUILTIN/10-omarchy") ]]'
stub omarchy-update-available 'echo "omarchy 3.1.0-1 -> 3.2.0-1"'
ok "omarchy: package update" '[[ $("$BUILTIN/10-omarchy") == "omarchy 3.1.0-1 3.2.0-1" ]]'
stub checkupdates 'printf "%s\n" "omarchy 1 -> 2" "jq 1.7-1 -> 1.8-1"'
ok "pacman: skips omarchy, keeps others" '[[ $("$BUILTIN/20-pacman") == "jq 1.7-1 1.8-1" ]]'
stub yay 'echo "foo-bin 1.0-1 -> 1.1-1"'
ok "aur: parses yay -Qua" '[[ $("$BUILTIN/30-aur") == "foo-bin 1.0-1 1.1-1" ]]'
stub mise "echo '{\"gh\":{\"current\":\"2.1\",\"latest\":\"2.2\"},\"amp\":{\"current\":null,\"latest\":\"9\"}}'"
ok "mise: skips never-installed tools" '[[ $("$BUILTIN/40-mise") == "gh 2.1 2.2" ]]'

# --- bad input
ok "rejects unknown command" '! "$TOOL" bogus 2>/dev/null'
ok "rejects unknown check option" '! "$TOOL" check --bogus 2>/dev/null'

echo "$pass passed, $fail failed"
((fail == 0))
