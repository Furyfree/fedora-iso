release := "44"
point := "1.7"
out := "out"
image := "Fedora-Everything-netinst-x86_64-" + release + "-" + point + ".iso"
checksum := "Fedora-Everything-" + release + "-" + point + "-x86_64-CHECKSUM"
iso_base := "https://download.fedoraproject.org/pub/fedora/linux/releases/" + release + "/Everything/x86_64/iso"

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
    curl -fL -C - -O "{{iso_base}}/{{image}}"
    sha256sum -c "$tmp/iso.sha256"

# Validate the kickstart against the supported release.
check:
    ksvalidator -v F{{release}} fedora-{{release}}.ks

# Build the install ISO from the official netinstall image in the repo root.
iso: fetch
    mkdir -p {{out}}
    sudo mkksiso --ks fedora-{{release}}.ks {{image}} {{out}}/fedora-{{release}}-nimbus.iso

# Build and publish the current ISO as a GitHub release. Requires gh auth.
release tag:
    just iso
    cd {{out}} && sha256sum fedora-{{release}}-nimbus.iso > SHA256SUMS
    gh release create {{tag}} {{out}}/fedora-{{release}}-nimbus.iso {{out}}/SHA256SUMS --title "Fedora {{release}} install media" --notes "Modified Fedora {{release}} Everything/netinstall ISO with the workstation kickstart. Not Fedora-signed; verify SHA256SUMS before writing."
