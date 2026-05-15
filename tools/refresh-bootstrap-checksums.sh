#!/usr/bin/env bash
# Print the values setup-devnads-com needs after any bootstrap script edit.
#
# Workflow:
#   1. Edit windows-bootstrap.ps1 / wsl-bootstrap.sh / mac-bootstrap.sh.
#   2. Commit + push so the new HEAD is permanent.
#   3. Run this from the repo root and copy the output into
#      setup-devnads-com's src/i18n/dictionaries/{en,tr}.ts:
#        - PINNED_REF       <- the new commit hash
#        - SHA.windows      <- windows-bootstrap.ps1 sha256
#        - SHA.wsl          <- wsl-bootstrap.sh sha256
#        - SHA.mac          <- mac-bootstrap.sh sha256

set -euo pipefail

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "Working tree is dirty; commit + push first so the pin matches what" >&2
  echo "users will actually fetch." >&2
  exit 1
fi

HEAD_SHA=$(git rev-parse HEAD)

printf 'PINNED_REF      %s\n' "$HEAD_SHA"
for f in windows-bootstrap.ps1 wsl-bootstrap.sh mac-bootstrap.sh; do
  if [ -f "$f" ]; then
    printf 'SHA  %-22s %s\n' "$f" "$(sha256sum "$f" | awk '{print $1}')"
  fi
done

echo
echo "Now update the matching constants in setup-devnads-com's dictionaries"
echo "and push. The website's one-liners will recompose from the new values."
