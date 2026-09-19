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

disk=""
for arg in $(cat /proc/cmdline); do
    case "$arg" in
        inst.disk=*) disk="${arg#inst.disk=}" ;;
    esac
done

disks=$(lsblk -dn -o NAME,TYPE | awk '$2 == "disk" {print $1}')
[ -n "$disks" ] || { echo "No installable disks found." >&2; exit 1; }
count=$(printf '%s\n' "$disks" | wc -l)

# Interact on the installer console; the graphical hub starts later.
if [ ! -t 0 ] && [ -r /dev/tty3 ] && [ -w /dev/tty3 ]; then
    exec </dev/tty3 >/dev/tty3 2>&1
    chvt 3 2>/dev/null || true
fi

if [ -z "$disk" ]; then
    if [ "$count" -eq 1 ]; then
        disk="/dev/$disks"
    else
        printf '\nNimbus installer - choose the target disk\n\n'
        i=0
        for name in $disks; do
            i=$((i + 1))
            model=$(lsblk -dn -o MODEL "/dev/$name" 2>/dev/null | xargs)
            size=$(lsblk -dn -o SIZE "/dev/$name" 2>/dev/null | xargs)
            hint=$(lsblk -n -o FSTYPE "/dev/$name" 2>/dev/null | grep -v '^$' | sort -u | paste -sd, -)
            printf '  %d) %-9s %-28s %-10s %s\n' "$i" "$name" "$model" "$size" "${hint:+($hint)}"
        done
        printf '\nChoose the target disk [1-%d]: ' "$i"
        read -r choice
        case "$choice" in
            ''|*[!0-9]*) echo "Invalid choice." >&2; exit 1 ;;
        esac
        if [ "$choice" -lt 1 ] || [ "$choice" -gt "$i" ]; then
            echo "Invalid choice." >&2
            exit 1
        fi
        disk="/dev/$(printf '%s\n' "$disks" | sed -n "${choice}p")"
    fi
fi

name=$(basename "$disk")
model=$(lsblk -dn -o MODEL "$disk" 2>/dev/null | xargs)
size=$(lsblk -dn -o SIZE "$disk" 2>/dev/null | xargs)
printf '\nThis will erase %s (%s, %s).\nType YES to continue: ' "$name" "$model" "$size"
read -r confirm
[ "$confirm" = YES ] || { echo "Aborted." >&2; exit 1; }

printf 'ignoredisk --only-use=%s\nclearpart --all --initlabel --drives=%s\n' "$disk" "$disk" > /tmp/disk.ks

if [ -r /dev/tty3 ] && [ -w /dev/tty3 ]; then
    chvt 1 2>/dev/null || true
fi
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
