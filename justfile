fedora := "44"
point := "1.7"
out := "out"
image := "Fedora-Everything-netinst-x86_64-" + fedora + "-" + point + ".iso"
checksum := "Fedora-Everything-" + fedora + "-" + point + "-x86_64-CHECKSUM"
iso_base := "https://download.fedoraproject.org/pub/fedora/linux/releases/" + fedora + "/Everything/x86_64/iso"

# Download and verify the official netinstall ISO for the configured release.
fetch:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{justfile_directory()}}"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL -o "$tmp/CHECKSUM" "{{iso_base}}/{{checksum}}"
    grep '^SHA256 (' "$tmp/CHECKSUM" | sed -E 's/^SHA256 \((.*)\) = ([0-9a-f]+)$/\2  \1/' > "$tmp/iso.sha256"
    if [ -f "{{image}}" ] && sha256sum -c "$tmp/iso.sha256" >/dev/null 2>&1; then
        echo "{{image}} is present and verified"
        exit 0
    fi
    if [ -f "{{image}}" ]; then
        remote="$(curl -fsIL "{{iso_base}}/{{image}}" | awk 'tolower($1) == "content-length:" {n = $2} END {gsub(/\r/, "", n); print n}')"
        local_size="$(stat -c %s "{{image}}")"
        if [ -n "$remote" ] && [ "$local_size" -lt "$remote" ]; then
            echo "Resuming {{image}}: $local_size of $remote bytes"
        else
            echo "{{image}} exists but does not match Fedora's checksum."
            read -r -p "Delete it and download fresh? [y/N] " answer
            case "$answer" in
                [yY]) rm -f "{{image}}" ;;
                *) echo "Kept the existing file; nothing downloaded." >&2; exit 1 ;;
            esac
        fi
    fi
    older=(Fedora-Everything-netinst-x86_64-{{fedora}}-*.iso)
    if [ -e "${older[0]}" ]; then
        echo "Other Fedora {{fedora}} media present: ${older[*]}"
        read -r -p "Remove those? [y/N] " answer
        case "$answer" in
            [yY]) rm -f "${older[@]}" ;;
        esac
    fi
    curl -fL -C - -O "{{iso_base}}/{{image}}"
    sha256sum -c "$tmp/iso.sha256"

# Validate the kickstart and the disk prompt.
check:
    ksvalidator -v F{{fedora}} fedora-{{fedora}}.ks
    sh tests/disk-prompt.test.sh
    if command -v shellcheck >/dev/null 2>&1; then shellcheck scripts/disk-prompt.sh; fi

# Build the install ISO from the official netinstall image in the repo root.
iso: fetch
    mkdir -p {{out}}/iso/nimbus
    cp scripts/disk-prompt.sh {{out}}/iso/nimbus/
    rm -f {{out}}/fedora-{{fedora}}-nimbus.iso
    sudo mkksiso --ks fedora-{{fedora}}.ks --add {{out}}/iso/nimbus {{image}} {{out}}/fedora-{{fedora}}-nimbus.iso
    (cd {{out}} && sha256sum fedora-{{fedora}}-nimbus.iso > SHA256SUMS)

# Build and publish the current ISO as the next v<fedora>.<n> release.
release:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{justfile_directory()}}"
    if [ -n "$(git status --porcelain)" ]; then
        echo "Worktree is not clean; commit or discard changes before releasing." >&2
        git status --short >&2
        exit 1
    fi
    git fetch --quiet origin main
    if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
        echo "HEAD is not origin/main; push or pull the release commit first." >&2
        exit 1
    fi
    git fetch --quiet --tags origin
    last="$(git tag -l --sort=-v:refname 'v{{fedora}}.*' | head -1)"
    if [ -n "$last" ]; then
        n="${last##*.}"
        case "$n" in
            ''|*[!0-9]*) echo "Unexpected release tag: $last" >&2; exit 1 ;;
        esac
    else
        n=0
    fi
    tag="v{{fedora}}.$((n + 1))"
    just iso
    notes="Source: {{image}}
    Commit: $(git rev-parse HEAD)
    SHA256: $(cut -d' ' -f1 {{out}}/SHA256SUMS)
    Modified Fedora {{fedora}} Everything/netinstall ISO with the workstation kickstart. Not Fedora-signed; verify SHA256SUMS before use."
    git tag -a "$tag" -m "$notes"
    git push origin "$tag"
    gh release create "$tag" --verify-tag "{{out}}/fedora-{{fedora}}-nimbus.iso" "{{out}}/SHA256SUMS" \
        --title "Fedora {{fedora}} install media $tag" --notes "$notes"