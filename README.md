# fedora-iso

Fedora workstation install media built from a kickstart. The kickstart
prefills the installer choices that are the same on every machine; disk,
LUKS passphrase, root, user and network stay interactive, and every prefilled
spoke can still be edited before install.

This is not a custom distribution image. `mkksiso` injects the kickstart into
the official Fedora Everything/netinstall ISO and leaves the signed boot
binaries untouched.

## What is prefilled

| Installer step | Value |
| --- | --- |
| Language | English (Denmark) |
| Keyboard | Danish, then English (US) |
| Time | Europe/Copenhagen, network time |
| Source | Fedora mirrorlist (netinstall) |
| Storage | EFI 1 GiB, ext4 `/boot` 2 GiB, LUKS2 btrfs, ten subvolumes |
| Software | Custom Operating System, Standard, NetworkManager submodules |

The btrfs subvolumes are root, home, snapshots, log, cache, swapfile,
flatpak, windows, docker and containerd.

Not prefilled on purpose: the target disk, the LUKS passphrase, root, the
user account, network and hostname. The kickstart never pins a disk, so the
prefilled layout applies to the disk you select.

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
just fetch
just check
just iso
```

`just fetch` downloads and verifies the official netinstall ISO for the
release configured at the top of the justfile; `just iso` runs it first. An
existing ISO is skipped once it verifies against Fedora's checksum; a partial
download resumes, a complete file that no longer matches asks before it is
deleted and re-downloaded, and other downloaded point releases are offered
for removal.

The result is `out/fedora-44-nimbus.iso`. Write it to a USB stick with Fedora
Media Writer or (replace `/dev/sdX` with the USB device):

```sh
sudo dd if=out/fedora-44-nimbus.iso of=/dev/sdX bs=8M status=progress conv=fsync
```

### Alternative: OEMDRV stick

Write the verified netinstall ISO from `just fetch` (or any official
netinstall media) to a USB as usual, then put the kickstart on a small FAT
volume labeled `OEMDRV`. Anaconda loads `/ks.cfg` automatically when the
stock media boots, so no rebuilt ISO is needed:

```sh
sudo parted /dev/sdX --script mklabel msdos mkpart primary fat32 1MiB 100%
sudo mkfs.vfat -n OEMDRV /dev/sdX1
sudo mount /dev/sdX1 /mnt
sudo cp fedora-44.ks /mnt/ks.cfg
sync && sudo umount /mnt
```

## Install

1. Boot the media in UEFI mode with Secure Boot on.
2. Installation Destination: select only the target disk.
3. The layout is waiting in Blivet; review or edit it, then press Done.
4. Enter the LUKS passphrase when prompted.
5. Check Software Selection (editable), then Begin Installation.
6. Finish the root and user prompts, then reboot.

After first boot, install Nimbus per the
[wiki](https://github.com/Furyfree/nimbus/wiki), and continue with the
[Nimbus postinstall steps](https://github.com/Furyfree/nimbus/wiki/Postinstall).

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

`just release v44.1` builds the ISO and publishes it as a GitHub release with
a `SHA256SUMS` file. It needs an authenticated `gh`. The `release` and
`point` values at the top of the justfile select the source media; bump
`point` after a Fedora respin. The ISO is not Fedora-signed; verify the
checksum before writing it. Add `fedora-<release>.ks` for a new Fedora
release.

## After install

- `/var/swap` is an empty subvolume. Create a swapfile only if needed
  (`chattr +C`, `btrfs filesystem mkswapfile`); Fedora already has zram.
- `docker`, `containerd` and `/var/lib/nimbus` may need `restorecon`, and VM
  images want `chattr +C`.
- Guest Agents is not selected; tick it for a VM install.

## License

MIT, see [LICENSE](LICENSE).
