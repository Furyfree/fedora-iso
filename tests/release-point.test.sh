#!/bin/sh
# Release points step up within a Fedora series and restart at 0 on a new one.
set -eu

root_dir=$(cd "$(dirname "$0")/.." && pwd)
point="$root_dir/scripts/release-point.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
git init -q
git commit -q --allow-empty -m init

expect() {
    got=$("$point" "$1")
    if [ "$got" != "$2" ]; then
        echo "release point for $1: got $got, want $2" >&2
        exit 1
    fi
}

expect 44 0
git tag -a v44.1 -m x
expect 44 2
git tag -a v44.2 -m x
expect 44 3
expect 45 0
git tag -a v44.11 -m x
expect 44 12
git tag -a v45.0 -m x
expect 45 1

git tag -a v47.oops -m x
if "$point" 47 >/dev/null 2>&1; then
    echo "malformed tag was accepted" >&2
    exit 1
fi

echo 'release-point tests passed'
