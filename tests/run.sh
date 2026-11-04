#!/usr/bin/env bash
# Test runner — no dependencies beyond bash.
#   tests/run.sh            run all tests
#   tests/run.sh prune      only tests whose name contains "prune"
#   tests/run.sh --docker   also run the end-to-end bootstrap in Ubuntu + Arch containers
set -u
cd "$(dirname "$0")" || exit 1
source ./lib.sh

filter='' docker=0
for a in "$@"; do
  case $a in --docker) docker=1 ;; *) filter=$a ;; esac
done

for f in ./test_*.sh; do source "$f"; done

if [[ -t 1 ]]; then G=$'\e[32m' Rd=$'\e[31m' D=$'\e[2m' N=$'\e[0m'; else G='' Rd='' D='' N=''; fi
pass=0 fail=0
failed=()
for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
  [[ -n $filter && $t != *"$filter"* ]] && continue
  T=$(mktemp -d "${TMPDIR:-/tmp}/dot-test.XXXXXX")
  out=$( (export T; new_sandbox; "$t") 2>&1 )
  rc=$?
  rm -rf "$T"
  if ((rc == 0)); then
    ((pass++)); printf '%s✓%s %s\n' "$G" "$N" "${t#test_}"
  else
    ((fail++)); failed+=("$t"); printf '%s✗ %s%s\n%s\n' "$Rd" "${t#test_}" "$N" "$out"
  fi
done

if ((docker)); then
  for img in ubuntu:24.04 archlinux:latest; do
    printf '%s… docker e2e on %s%s\n' "$D" "$img" "$N"
    if ./docker-e2e.sh "$img"; then ((pass++)); printf '%s✓%s e2e %s\n' "$G" "$N" "$img"
    else ((fail++)); failed+=("e2e $img"); printf '%s✗ e2e %s%s\n' "$Rd" "$img" "$N"; fi
  done
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
((fail == 0)) || { printf 'failed: %s\n' "${failed[*]}"; exit 1; }
