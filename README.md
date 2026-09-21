# fedora-iso

Personal Fedora install media built from the official Everything/netinstall
ISO. The kickstart supplies the workstation layout and package selection;
`mkksiso` adds it without replacing Fedora's signed boot binaries.

## Build

Use Fedora with `just`, `pykickstart`, `lorax`, `curl` and `pkexec` installed.
ShellCheck is optional. The build requests root access through a PolicyKit
approval prompt. On Windows, use the Fedora WSL provisioned by
[win-setup](https://github.com/Furyfree/win-setup); it needs the same tools
and a working PolicyKit authentication agent.

```sh
just check          # validate the kickstart and run shell tests
just fetch          # download and verify the official netinstall ISO
just iso            # check, fetch, then build out/fedora-44-nimbus.iso
```

The Fedora release comes from the single `fedora-<release>.ks`; `point` in
`justfile` pins the official respin. Fetch reuses a verified ISO, resumes
partial downloads and asks before deleting mismatched or older media.
The build also writes `out/SHA256SUMS`.

## Install

Boot the ISO. The console lists the disks and asks which to erase, then
requires `YES`. With one disk, it only asks for confirmation. Aborting or
losing console input stops installation before erasing a disk.

**The selected disk is erased.** The boot option
`inst.disk=/dev/disk/by-id/...` selects it directly and bypasses confirmation.

Complete the startup LUKS passphrase dialog. Do not cancel it or open
Installation Destination and press Done: either discards the kickstart
layout. Choose Closest mirror for the installation source, and fill in the
root, user, network and hostname settings. See
[fedora-44.ks](fedora-44.ks) for the preset layout, locale and packages.

Before using changed media on hardware, test in a disposable UEFI VM with
Secure Boot and two disks, including an NTFS partition on the second:

- Select the target, confirm the wipe and check that the other disk survives.
- Check the LUKS prompt and editable software selection.
- Boot the installed system and check its encryption and subvolumes.

## Release

From a clean `main` matching `origin/main`, with `gh` authenticated:

```sh
just release
```

This checks and builds the ISO, pushes an annotated `v<fedora>.<n>` tag and
publishes the ISO with `SHA256SUMS`. Numbering starts at `.0` for each Fedora
release. The tag and release notes record the source image, commit and
checksum. The modified ISO is not Fedora-signed; verify its checksum.

If upload fails after the tag is pushed, retry with that tag and its notes:

```sh
git tag -l --format='%(contents)' <tag> > /tmp/fedora-iso-release-notes.txt
gh release create <tag> --verify-tag out/fedora-44-nimbus.iso out/SHA256SUMS \
    --notes-file /tmp/fedora-iso-release-notes.txt
```

## After install

- `/var/swap` is empty. Create a swapfile only if needed; Fedora has zram.
- Docker, containerd and `/var/lib/nimbus` may need `restorecon`; use
  `chattr +C` for directories that will hold VM images.
- Select Guest Agents when installing in a VM.

[MIT license](LICENSE).
