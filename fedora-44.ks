# Fedora 44 workstation: pre-filled layout and package selection.
#
# The kickstart fills in the installer choices that are the same on every
# machine. The target disk is chosen on the installer console before the GUI
# starts and pinned for the rest of the install; the LUKS passphrase, root,
# user and network stay interactive. Do not open Installation Destination,
# and complete (do not cancel) the startup passphrase dialog.
#
# Validate with `just check`.

#version=F44

%pre
set -eu

# Fail safely until the prompt writes a confirmed disk: an unknown disk stops
# the installer instead of letting it guess.
printf 'ignoredisk --only-use=/dev/nimbus-no-disk-selected\n' > /tmp/disk.ks

disk=""
for arg in $(cat /proc/cmdline); do
    case "$arg" in
        inst.disk=*) disk="${arg#inst.disk=}" ;;
    esac
done

if [ -n "$disk" ]; then
    printf 'ignoredisk --only-use=%s\nclearpart --all --initlabel --drives=%s\n' "$disk" "$disk" > /tmp/disk.ks
    exit 0
fi

prompt=""
for base in /run/install/repo /mnt/install/repo; do
    if [ -r "$base/nimbus/disk-prompt.sh" ]; then
        prompt="$base/nimbus/disk-prompt.sh"
        break
    fi
done
[ -n "$prompt" ] || { echo "nimbus: disk-prompt.sh not found on the media" >&2; exit 1; }

# %pre stdout is a pipe; the installer console is /dev/tty (the tmux pane on
# tty1). Ask and read there so the prompt is visible and the answer arrives.
[ -r /dev/tty ] && [ -w /dev/tty ] || { echo "nimbus: /dev/tty unavailable" >&2; exit 1; }
/bin/sh "$prompt" </dev/tty >/dev/tty 2>&1
%end

lang en_DK.UTF-8
keyboard --vckeymap=dk --xlayouts='dk','us'
timezone Europe/Copenhagen --utc

# Installation Source is left to the installer: choose Closest mirror.

# The target disk was pinned above. Installation Destination must not be
# opened: pressing Done there replaces this layout with automatic partitioning.
%include /tmp/disk.ks

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
