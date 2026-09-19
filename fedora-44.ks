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

# Keep a safe placeholder until the target disk is confirmed. Including an
# unknown disk stops the installer instead of letting it guess a disk.
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

cat > /tmp/nimbus-disk-prompt.sh <<'PROMPT'
#!/bin/sh
set -eu

disks=$(lsblk -dn -o NAME,TYPE | awk '$2 == "disk" {print $1}')
[ -n "$disks" ] || { echo "No installable disks found." >&2; exit 1; }
count=$(printf '%s\n' "$disks" | wc -l)

if [ "$count" -eq 1 ]; then
    chosen="$disks"
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
    chosen=$(printf '%s\n' "$disks" | sed -n "${choice}p")
fi

model=$(lsblk -dn -o MODEL "/dev/$chosen" 2>/dev/null | xargs)
size=$(lsblk -dn -o SIZE "/dev/$chosen" 2>/dev/null | xargs)
printf '\nThis will erase %s (%s, %s).\nType YES to continue: ' "$chosen" "$model" "$size"
read -r confirm
[ "$confirm" = YES ] || { echo "Aborted." >&2; exit 1; }

printf 'ignoredisk --only-use=/dev/%s\nclearpart --all --initlabel --drives=/dev/%s\n' "$chosen" "$chosen" > /tmp/disk.ks
PROMPT
chmod +x /tmp/nimbus-disk-prompt.sh

# Ask on its own virtual console; switch back afterwards.
openvt -s -w -- /bin/sh /tmp/nimbus-disk-prompt.sh
chvt 1 2>/dev/null || true
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
