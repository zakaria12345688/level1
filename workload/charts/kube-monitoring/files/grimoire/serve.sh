#!/bin/sh
# Serves the grimoire over HTTP. Creates it from the genesis pages on first
# start.
set -eu
export HOME=/tmp
git config --global safe.directory '*'
git config --global init.defaultBranch main
REPO=/srv/git/realm.git
if [ ! -f "$REPO/HEAD" ]; then
  echo "[grimoire] writing the genesis"
  git init --bare -q "$REPO"
  work=$(mktemp -d)
  cp -rL /genesis/pages/. "$work/"
  cd "$work"
  git init -q
  git add -A
  GIT_AUTHOR_NAME="Guild of Architects" GIT_AUTHOR_EMAIL="architects@guild.achrona.realm" \
  GIT_COMMITTER_NAME="Guild of Architects" GIT_COMMITTER_EMAIL="architects@guild.achrona.realm" \
    git commit -q -m "Genesis: the Seer awakens"
  git push -q "$REPO" HEAD:main
  cd / && rm -rf "$work"
fi
cp /genesis/update-hook "$REPO/hooks/update"
chmod +x "$REPO/hooks/update"
git -C "$REPO" config http.receivepack true
exec python3 -u /genesis/serve.py
