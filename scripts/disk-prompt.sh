#!/bin/sh
# Ask for the target disk on the installer console and write the kickstart
# storage fragment. Run from the kickstart's %pre through openvt.
set -eu

target="${DISK_KS:-/tmp/disk.ks}"

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

printf 'ignoredisk --only-use=/dev/%s\nclearpart --all --initlabel --drives=/dev/%s\n' \
    "$chosen" "$chosen" > "$target"
