# Repository map

- `fedora-<release>.ks`: the single kickstart; `#version=F<release>` selects
  the Fedora release. Disk selection happens at install time. Never hard-code
  a target disk or store passphrases or account credentials.
- `justfile`: fetch, validate, build and release. `point` pins the official
  respin; `scripts/release-point.sh` derives release numbers from Git tags.
- `scripts/disk-prompt.sh`: console disk selection, shipped with `mkksiso`
  using `--add`. Writes the storage fragment only after confirmation.
- `tests/*.test.sh`: disk prompt, release numbering and build safeguards.
- `README.md`: usage and the VM drill required before hardware.

Use native Fedora tooling and official netinstall media. Preserve signed
boot binaries and verify real checksums. Run `just check` after changes;
its fake-command tests do not replace the UEFI Secure Boot VM drill.
Never commit secrets, private paths or built media.
