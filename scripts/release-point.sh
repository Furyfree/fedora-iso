#!/usr/bin/env bash
# Print the next release point for a Fedora version: one past the highest
# existing v<fedora>.<n> tag, or 0 when that Fedora has no releases yet.
set -euo pipefail

fedora="${1:?usage: release-point.sh <fedora>}"

last="$(git tag -l --sort=-v:refname "v${fedora}.*" | head -1)"
if [ -z "$last" ]; then
    echo 0
    exit 0
fi
n="${last##*.}"
case "$n" in
    ''|*[!0-9]*)
        echo "Unexpected release tag: $last" >&2
        exit 1
        ;;
esac
echo $((n + 1))
