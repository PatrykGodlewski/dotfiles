#!/usr/bin/env bash
# End-to-end: fresh container -> install.sh -> dot apply @minimal -> verify.
# Uses the working tree (uncommitted changes included). Needs docker.
#   tests/docker-e2e.sh ubuntu:24.04
#   tests/docker-e2e.sh archlinux:latest
set -u
img=${1:-ubuntu:24.04}
repo=$(cd "$(dirname "$0")/.." && pwd)

inner='
set -u
export NO_COLOR=1 DOT_WSL=0
cp -r /src /tmp/repo && cd /tmp/repo &&
  git -c user.email=t@t -c user.name=t add -A >/dev/null &&
  git -c user.email=t@t -c user.name=t commit -qm wip >/dev/null && git branch -M main
cd ~
echo "existing" > ~/.gitconfig
DOT_NO_MENU=1 DOTFILES_REPO=/tmp/repo bash /tmp/repo/install.sh >/tmp/install.log 2>&1 || { tail -30 /tmp/install.log; exit 1; }
export PATH="$HOME/.local/bin:$PATH"
command -v gum >/dev/null || { echo "FAIL: gum missing after bootstrap"; exit 1; }
dot apply @minimal --yes >/tmp/apply.log 2>&1 || { tail -40 /tmp/apply.log; exit 1; }
nvim --version | head -1 | grep -q "NVIM v0.1[1-9]" || { echo "FAIL: nvim version"; exit 1; }
[ -L ~/.config/nvim ] && [ -L ~/.zshrc ] && [ -L ~/.gitconfig ] || { echo "FAIL: links"; exit 1; }
[ "$(cat ~/.local/state/dotfiles/backups/*/.gitconfig)" = existing ] || { echo "FAIL: backup"; exit 1; }
dot apply --yes 2>&1 | grep -q "Everything is already applied" || { echo "FAIL: not idempotent"; exit 1; }
dot remove tmux --yes >/dev/null 2>&1 && [ ! -e ~/.config/tmux ] || { echo "FAIL: remove"; exit 1; }
echo E2E_OK
'

case $img in
  *arch*) prep='pacman -Sy --noconfirm --needed sudo git >/dev/null 2>&1' ;;
  *) prep='apt-get update -qq >/dev/null && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq sudo git >/dev/null 2>&1' ;;
esac

docker run --rm -v "$repo:/src:ro" "$img" bash -c "
$prep
useradd -m -s /bin/bash dev && echo 'dev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/dev
su - dev -c '$(printf '%s' "$inner" | sed "s/'/'\\\\''/g")'
" 2>&1 | tail -20 | tee /dev/stderr | grep -q E2E_OK
