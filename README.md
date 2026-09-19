# fedora-iso

Fedora workstation install media built from a kickstart. The kickstart
prefills the installer choices that are the same on every machine. The target
disk is chosen on the installer console before the GUI starts, then pinned
for the rest of the install; the LUKS passphrase, root, user and network stay
interactive.

This is not a custom distribution image. `mkksiso` injects the kickstart into
the official Fedora Everything/netinstall ISO and leaves the signed boot
binaries untouched.

## What is prefilled

| Installer step | Value |
| --- | --- |
| Language | English (Denmark) |
| Keyboard | Danish, then English (US) |
| Time | Europe/Copenhagen, network time |
| Storage | EFI 1 GiB, ext4 `/boot` 2 GiB, LUKS2 btrfs, ten subvolumes |
| Software | Custom Operating System, Standard, NetworkManager submodules |

The btrfs subvolumes are root, home, snapshots, log, cache, swapfile,
flatpak, windows, docker and containerd.

Not prefilled on purpose: the installation source (choose Closest mirror),
the LUKS passphrase, root, the user account, network and hostname.

## Choosing the disk

Before the graphical installer starts, the kickstart lists the local disks
with their model, size and existing filesystems, asks which one to install
to, and requires a `YES` confirmation because that disk is erased. With a
single disk it selects it automatically and only asks for the confirmation.

Boot with `inst.disk=/dev/disk/by-id/...` to skip the menu; the confirmation
still runs. That is also the fallback if the console prompt ever fails.

Do not open Installation Destination: pressing Done there replaces the
kickstart layout with automatic partitioning. Complete the startup LUKS
passphrase dialog; cancelling it discards the layout too.

## Build

### Fedora

```sh
sudo dnf install -y just pykickstart lorax
```

### Windows

Build inside the Fedora WSL that
[win-setup](https://github.com/Furyfree/win-setup) provisions, with the same
packages as Fedora (`just`, `pykickstart`, `lorax`).

### Arch Linux

`just` is in the official repositories; the AUR carries `lorax` and
`python-pykickstart`. The AUR packages are unofficial and untested here.

```sh
sudo pacman -S just
# install lorax and python-pykickstart from the AUR
```

### Build the media

From the repository checkout, on any of the platforms above:

```sh
just fetch          # download and verify the official netinstall ISO
just check          # validate the kickstart
just iso            # build out/fedora-44-nimbus.iso
just release        # the same build, published as a GitHub release
```

`just fetch` downloads and verifies the official netinstall ISO for the
release configured at the top of the justfile; `just iso` runs it first. An
existing ISO is skipped once it verifies against Fedora's checksum; a partial
download resumes, a complete file that no longer matches asks before it is
deleted and re-downloaded, and other downloaded point releases are offered
for removal.

The result is `out/fedora-44-nimbus.iso`: the official netinstall media with
the kickstart injected, for the standard UEFI Secure Boot install flow. Disk
selection, the LUKS passphrase, root and the user stay interactive, and the
prefilled spokes remain editable.

## Drill before real hardware

Test any change in a disposable UEFI VM with Secure Boot and two disks, the
second holding an NTFS partition:

- the layout follows the disk you select, and the second disk is unchanged;
- the LUKS passphrase prompt appears;
- software selection is prefilled and editable;
- the installed system boots with the subvolumes and encryption intact.

The kickstart never uses `clearpart` or `--ondisk`; if you want to reuse a
disk, reclaim its space in the storage spoke rather than automating a wipe.

## Releases

`just release` builds the ISO and publishes it as the GitHub release
`v<fedora>.<revision>`, currently `v44.1`, with a `SHA256SUMS` file. It needs
an authenticated `gh`. The ISO is not Fedora-signed.

Three values at the top of the justfile control this:

- `fedora` and `point` select the official netinstall media (`44-1.7`).
- `revision` is this repository's release number for that media.

Bump `revision` for any kickstart or tooling change. Update `point` when
Fedora respins the media, and bump `revision` with it. A new Fedora release
needs `fedora-<release>.ks` (with a matching mirrorlist URL), then `fedora`,
`point` and `revision` set to that media.

## After install

- `/var/swap` is an empty subvolume. Create a swapfile only if needed
  (`chattr +C`, `btrfs filesystem mkswapfile`); Fedora already has zram.
- `docker`, `containerd` and `/var/lib/nimbus` may need `restorecon`, and VM
  images want `chattr +C`.
- Guest Agents is not selected; tick it for a VM install.

## License

MIT, see [LICENSE](LICENSE).
