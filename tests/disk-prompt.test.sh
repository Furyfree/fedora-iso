#!/bin/sh
# Regression tests for scripts/disk-prompt.sh with a fake lsblk.
set -eu

root_dir=$(cd "$(dirname "$0")/.." && pwd)
prompt="$root_dir/scripts/disk-prompt.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"

cat > "$tmp/bin/lsblk" <<'EOF'
#!/bin/sh
case "$*" in
  '-dn -o NAME,TYPE') printf 'nvme0n1 disk\nnvme1n1 disk\n' ;;
  '-dn -o MODEL /dev/nvme0n1') echo 'Samsung SSD 990 PRO 2TB' ;;
  '-dn -o MODEL /dev/nvme1n1') echo 'WD500G1X0E-00AFY0' ;;
  '-dn -o SIZE /dev/nvme0n1') echo '1.8T' ;;
  '-dn -o SIZE /dev/nvme1n1') echo '465.8G' ;;
  '-n -o FSTYPE /dev/nvme0n1') printf 'btrfs\n' ;;
  '-n -o FSTYPE /dev/nvme1n1') printf '\n' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/lsblk"

run() {
    DISK_KS="$tmp/disk.ks" PATH="$tmp/bin:$PATH" sh "$prompt"
}

rm -f "$tmp/disk.ks"
printf '2\nYES\n' | run >/dev/null
grep -qx 'ignoredisk --only-use=/dev/nvme1n1' "$tmp/disk.ks"
grep -qx 'clearpart --all --initlabel --drives=/dev/nvme1n1' "$tmp/disk.ks"

rm -f "$tmp/disk.ks"
if printf '1\nno\n' | run >/dev/null 2>&1; then
    echo "abort was accepted" >&2
    exit 1
fi
[ ! -e "$tmp/disk.ks" ]

if printf '9\n' | run >/dev/null 2>&1; then
    echo "invalid choice was accepted" >&2
    exit 1
fi

cat > "$tmp/bin/lsblk" <<'EOF'
#!/bin/sh
case "$*" in
  '-dn -o NAME,TYPE') printf 'nvme0n1 disk\n' ;;
  '-dn -o MODEL /dev/nvme0n1') echo 'Samsung SSD 990 PRO 2TB' ;;
  '-dn -o SIZE /dev/nvme0n1') echo '1.8T' ;;
  '-n -o FSTYPE /dev/nvme0n1') printf 'btrfs\n' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/lsblk"

rm -f "$tmp/disk.ks"
printf 'YES\n' | run >/dev/null
grep -qx 'clearpart --all --initlabel --drives=/dev/nvme0n1' "$tmp/disk.ks"

echo 'disk-prompt tests passed'
