# Handoff — HighPoint SSD7505 patcher session (2026-11-02)

Continuation notes from the Skynet workstation session. Everything code-side is
committed to `main`; pull it anywhere to continue. **The SSD7505 HBA exists
only on the Skynet host — steps needing it are marked `[HBA REQUIRED]`.**

## Verified state on the dev host (Skynet, kernel 7.3.0-10-generic)

- RAID-0 assembled and live: `hptblock8n0p` (14.6T) with ESP + `kubuntu_2404`
  (xfs, UUID `2c207cb7-1be6-43d2-8592-ed30457e2b13`); root stays on SATA `sda1`.
- All five PCI functions bound to `hptnvme` (`05/06/07/08:00.0` members,
  `0b:00.0` HBA).
- Generic `nvme` driver blacklisted in **both** initramfs images.
- `hptnvme.ko` baked into `initrd.img-7.3.0-10-generic`
  (`usr/lib/modules/7.3.0-10-generic/updates/dkms/hptnvme.ko.zst`).
- `hptnvme` registered at line 12 of `/etc/initramfs-tools/modules`.
- dkms: `hptnvme/1.6.22.0, 7.3.0-10-generic, x86_64: installed`.

## Root cause that was diagnosed (for the record)

At boot the generic in-tree `nvme` driver bound all four member drives during
the **initramfs stage** (`dmesg`: `nvme nvme0-3: pci function …` at t≈1.1s),
while `hptnvme` only loaded at t≈25.4s via udev coldplug — both match the same
class alias `pci:v*d*sv*sd*bc01sc08i02*`. The kernel never rebinds a device
already in use, so `hptnvme` got only the HBA function, logged
`Verify controller success` / `probe vbus`, and stalled with no volume. The
fix is the `blacklist nvme` in `/etc/modprobe.d/hptnvme-blacklist.conf`
(baked into both initramfs images).

## Changes in this session

1. **`/etc/modprobe.d/hptnvme-blacklist.conf`** — `blacklist nvme`, then
   `update-initramfs -u -k all`. Removes the race entirely: the members'
   modalias now resolves only to `hptnvme`.
2. **`hpt_modern_patcher.sh`** — after `dkms install`, the DKMS branch now
   registers `hptnvme` in `/etc/initramfs-tools/modules` (idempotent) and runs
   `update-initramfs -u -k all`, so every installer run rebuilds the kernel
   images with the driver inside. Verified end-to-end with an expect-driven
   run (exit 0): `-> Rebuilding kernel images for all installed kernels...` →
   `-> Kernel images rebuilt successfully.`, module visible in the image.
3. **`.gitignore`** — vendor tarball stays local (HighPoint license; README
   documents the manual download flow the patcher scans for).

## Next steps — at home (no HBA needed)

- [ ] Build the dkms module for the secondary kernel (its initramfs has the
      blacklist but **no** `hptnvme.ko`, because dkms only built for the
      running kernel):
      `sudo dkms install -m hptnvme -v 1.6.22.0 -k 7.3.0-9-generic`
      (requires `linux-headers-7.3.0-9-generic`), then
      `sudo update-initramfs -u -k all`. Consider making the installer loop
      `dkms install -k <every kernel in /lib/modules>` instead of only
      `uname -r` — it already runs `dkms remove --all`, so the other kernel
      currently loses its build on every patcher run.
- [ ] Harden extraction in the patcher for non-TTY runs (see Quirks).
- [ ] Cosmetic: dkms prints `Warning: The post_build script is not executable`
      — dkms signs the module itself during install anyway; either drop
      `POST_BUILD` from the generated `dkms.conf` or make it a real script.

## Next steps — `[HBA REQUIRED]` back on Skynet

- [ ] **Reboot test of the boot-time assembly** (the whole point of the
      blacklist). After boot expect:
      - `sudo dmesg | grep hptnvme` → `probe controller` lines for `[05]`–`[08]`
        (not just `Verify controller success` + `probe vbus`),
      - `lsblk` shows `hptblock8n0p` without any manual bind dance,
      - `journalctl -b 0 | grep 'nvme nvme'` → **no** `pci function` lines for
        `05/06/07/08:00.0` (blacklist holding),
      - `sudo lsinitramfs /boot/initrd.img-$(uname -r) | grep hptnvme.ko` → present.
- [ ] Boot-from-array work (root currently on SATA): move root to
      `hptblock8n0p2`, keep blacklist + initramfs module, verify GRUB/earlyboot.

## Quirks discovered while testing (affect automation, not interactive use)

- The vendor `.bin` is a Makeself archive: **if stdin is not a TTY and
  DISPLAY is set**, it relaunches itself via `konsole -title … -e $0 --xwin
  "--noexec --target DIR"` — the flags collapse into one argument, extraction
  silently no-ops, and the script dies at `find …/extracted`. Interactive
  terminal runs are unaffected. Automate with a PTY (`script -qec` or expect).
- Piped answers (`printf 'y\nn\n' | script …`) are consumed/echoed before the
  prompts appear and get lost. Drive the prompts with **expect** pattern
  matching instead (see `/tmp/run_patcher.exp` pattern from this session).
- `dmesg` is restricted for non-root here → `sudo dmesg`.
- `/boot` images are mode 600 → `lsinitramfs` needs sudo.
