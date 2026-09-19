# Fedora 44 workstation: pre-filled layout and package selection.
#
# The kickstart fills in the installer choices that are the same on every
# machine. It never pins a disk, stores a LUKS passphrase, or sets account
# credentials. Disk selection, passphrase, root, user and network stay
# interactive, and every prefilled spoke can still be edited before install.
#
# Validate with `just check`.

#version=F44

lang en_DK.UTF-8
keyboard --vckeymap=dk --xlayouts='dk','us'
timezone Europe/Copenhagen --utc
url --mirrorlist="https://mirrors.fedoraproject.org/metalink?repo=fedora-44&arch=x86_64"

part /boot/efi --fstype=efi --size=1024
part /boot --fstype=ext4 --size=2048
part btrfs.01 --fstype=btrfs --size=1 --grow --encrypted --luks-version=luks2

btrfs none --label=fedora btrfs.01
btrfs / --subvol --name=root LABEL=fedora
btrfs /home --subvol --name=home LABEL=fedora
btrfs /.snapshots --subvol --name=snapshots LABEL=fedora
btrfs /var/log --subvol --name=log LABEL=fedora
btrfs /var/cache --subvol --name=cache LABEL=fedora
btrfs /var/swap --subvol --name=swapfile LABEL=fedora
btrfs /var/lib/flatpak --subvol --name=flatpak LABEL=fedora
btrfs /var/lib/nimbus/windows --subvol --name=windows LABEL=fedora
btrfs /var/lib/docker --subvol --name=docker LABEL=fedora
btrfs /var/lib/containerd --subvol --name=containerd LABEL=fedora

bootloader

%packages
@^custom-environment
@standard
@networkmanager-submodules
%end
