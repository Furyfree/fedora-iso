fedora := "44"
out := "out"

# Validate the kickstart against the supported release.
check:
    ksvalidator -v F{{fedora}} fedora-{{fedora}}.ks

# Build the install ISO from the official netinstall image in the repo root.
iso:
    mkdir -p {{out}}
    sudo mkksiso --ks fedora-{{fedora}}.ks Fedora-Everything-netinst-x86_64-{{fedora}}-*.iso {{out}}/fedora-{{fedora}}-nimbus.iso

# Build and publish the current ISO as a GitHub release. Requires gh auth.
release tag:
    just iso
    cd {{out}} && sha256sum fedora-{{fedora}}-nimbus.iso > SHA256SUMS
    gh release create {{tag}} {{out}}/fedora-{{fedora}}-nimbus.iso {{out}}/SHA256SUMS --title "Fedora {{fedora}} install media" --notes "Modified Fedora {{fedora}} Everything/netinstall ISO with the workstation kickstart. Not Fedora-signed; verify SHA256SUMS before writing."
