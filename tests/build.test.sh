#!/bin/sh
# Run the real recipes in a scratch checkout with external operations replaced.
set -eu
root_dir=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/scripts" "$tmp/tests"
cp "$root_dir/justfile" "$tmp/justfile"
cp "$root_dir/scripts/"*.sh "$tmp/scripts/"
printf '#version=F99\n' > "$tmp/fedora-99.ks"
# Nested `iso` still runs check, without recursively running this test suite.
for test in disk-prompt release-point build; do
    printf '#!/bin/sh\nexit 0\n' > "$tmp/tests/$test.test.sh"
done
export PATH="$tmp/bin:$PATH"
export EVENTS="$tmp/events" VALIDATION=0 BRANCH=main DIRTY='' HEAD_ID=abc
cat > "$tmp/bin/ksvalidator" <<'STUB'
#!/bin/sh
printf 'validate\n' >> "$EVENTS"
exit "$VALIDATION"
STUB
cat > "$tmp/bin/curl" <<'STUB'
#!/bin/sh
set -eu
printf 'curl\n' >> "$EVENTS"
case "$1" in
    -fsSL)
        digest=$(printf complete | sha256sum | cut -d' ' -f1)
        printf 'SHA256 (%s) = %s\n' "$IMAGE" "$digest" > "$3" ;;
    -fsIL) printf 'Content-Length: 8\r\n' ;;
    -fL)
        size=0
        [ ! -f "$IMAGE" ] || size=$(stat -c %s "$IMAGE")
        printf 'download:%s\n' "$size" >> "$EVENTS"
        printf complete > "$IMAGE" ;;
    *) exit 1 ;;
esac
STUB
cat > "$tmp/bin/pkexec" <<'STUB'
#!/bin/sh
set -eu
# Without this, pkexec changes to root's home and relative build paths fail.
[ "$1" = --keep-cwd ]
shift
[ "$1" = /usr/bin/mkksiso ]
printf 'build\n' >> "$EVENTS"
for arg do output="$arg"; done
printf 'built media\n' > "$output"
STUB
cat > "$tmp/bin/git" <<'STUB'
#!/bin/sh
case "$*" in
    'branch --show-current') printf '%s\n' "$BRANCH" ;;
    'status --porcelain'|'status --short') printf '%s' "$DIRTY" ;;
    'rev-parse HEAD') printf '%s\n' "$HEAD_ID" ;;
    'rev-parse origin/main') echo abc ;;
    'fetch --quiet origin main') echo fetch >> "$EVENTS" ;;
    *) echo "Unexpected Git operation: $*" >> "$EVENTS"; exit 1 ;;
esac
STUB
cat > "$tmp/bin/gh" <<'STUB'
#!/bin/sh
echo 'Unexpected publication' >&2
exit 1
STUB
chmod +x "$tmp/bin/"*
cd "$tmp"
IMAGE=$(just --evaluate image)
export IMAGE
older=Fedora-Everything-netinst-x86_64-99-old.iso

# Removing older media must preserve the resumable current download.
printf part > "$IMAGE"
printf old > "$older"
: > "$EVENTS"
printf 'y\n' | just fetch >/dev/null
[ ! -e "$older" ]
grep -qx 'download:4' "$EVENTS"

# With no older media there must be no deletion prompt for the current ISO.
printf part > "$IMAGE"
just fetch </dev/null >/dev/null

# Declining cleanup preserves older media; declining replacement preserves bad media.
printf part > "$IMAGE"
printf old > "$older"
printf 'n\n' | just fetch >/dev/null
[ "$(cat "$older")" = old ]
printf corrupt! > "$IMAGE"
if printf 'n\n' | just fetch >/dev/null 2>&1; then
    echo 'declined replacement succeeded' >&2; exit 1
fi
[ "$(cat "$IMAGE")" = corrupt! ]

# A verified download is reused.
printf complete > "$IMAGE"
: > "$EVENTS"
just fetch </dev/null >/dev/null
if grep -q '^download:' "$EVENTS"; then
    echo 'verified media was downloaded again' >&2; exit 1
fi

# Validation failure must stop before downloads or replacing the built image.
mkdir -p out
printf existing > out/fedora-99-nimbus.iso
VALIDATION=1
: > "$EVENTS"
if just iso >/dev/null 2>&1; then
    echo 'build ignored failed validation' >&2; exit 1
fi
[ "$(cat "$EVENTS")" = validate ]
[ "$(cat out/fedora-99-nimbus.iso)" = existing ]
VALIDATION=0
just iso >/dev/null
(cd out && sha256sum -c SHA256SUMS >/dev/null)
grep -qx build "$EVENTS"

# A branch at the same commit as main, or detached HEAD, is not releasable.
for BRANCH in feature ''; do
    : > "$EVENTS"
    if just release >/dev/null 2>&1; then
        echo 'release outside main succeeded' >&2; exit 1
    fi
    [ ! -s "$EVENTS" ]
done
BRANCH=main
DIRTY=' M justfile'
if just release >/dev/null 2>&1; then
    echo 'dirty release succeeded' >&2; exit 1
fi
[ ! -s "$EVENTS" ]
DIRTY=''
HEAD_ID=behind
if just release >/dev/null 2>&1; then
    echo 'out-of-sync release succeeded' >&2; exit 1
fi
[ "$(cat "$EVENTS")" = fetch ]

echo 'build tests passed'
