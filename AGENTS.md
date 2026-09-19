# Repository instructions

Personal Fedora workstation install media built from a kickstart.

- One kickstart per Fedora release (`fedora-<release>.ks`). It prefills the
  documented layout and package selection and never pins a disk, stores a
  LUKS passphrase, or sets account credentials.
- Build only with native Fedora tooling (pykickstart, lorax `mkksiso`) from
  the official netinstall ISO. Never replace or re-sign boot binaries, and
  never use a placeholder checksum.
- `just check` validates the kickstart. Test every change in a disposable
  UEFI VM with Secure Boot and a second disk before real hardware.
- The README is the only usage document; keep it short. Releases carry the
  built, unsigned ISO with its `SHA256SUMS`.
- The disk prompt is `scripts/disk-prompt.sh`, shipped on the ISO with
  `mkksiso --add` and covered by `tests/disk-prompt.test.sh`; keep
  `just check` green.
- Release numbers come from git tags (`v<fedora>.<n>`); cut releases
  with `just release`, never by editing a version.
- Never commit secrets, credentials, private paths or built media.
