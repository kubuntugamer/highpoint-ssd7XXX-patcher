# Handoff — HighPoint SSD7505 patcher session (2026-11-03)

Everything code-side is committed to `main`; pull it anywhere to continue. The
SSD7505 HBA is present on **Skynet** (this machine) — items marked
`[HBA REQUIRED]` only work there.

## Two installs on this machine — do not confuse them

| | SATA root (`/dev/sda1`) | Array root (`/dev/hptblock6n0p2`) |
|---|---|---|
| Use | the running system | the target being built |
| Mounted at | `/` | `/home/chazz/target` |
| Kernel running | 7.3.0-10-generic | n/a (boots 7.0.0-15-generic) |
| Release | — | Ubuntu 26.04.1 LTS, label `kubuntu_2404` |
| hptnvme module | dkms, both kernels | dkms, 9 kernels (see below) |

The array root is what must boot from the HighPoint RAID-0. The SATA root is
only how you get a working machine to repair/build it.

## Verified state on the SATA root (kernel 7.3.0-10-generic)

- Boot-time assembly works unattended: `hptnvme` loads from initramfs at
  t≈0.72s and probes `[05]`–`[08]` at t≈1.69–1.72s, before the generic driver
  can claim them. No `nvme nvmeN: pci function` lines.
- All four Phison E12 members bound to `hptnvme`; `/sys/bus/pci/drivers/nvme`
  is empty. Array appears as `hptblock6n0p` (14.6T). **The block major varies
  per boot** (`hptblock6n0p` / `hptblock8n0p`) — match on the xfs UUID
  `2c207cb7-1be6-43d2-8592-ed30457e2b13`, not the device name.
- `blacklist nvme` in `/etc/modprobe.d/hptnvme-blacklist.conf`, present in both
  initramfs images; `hptnvme.ko.zst` present in both; `hptnvme` listed at line
  12 of `/etc/initramfs-tools/modules`.
- dkms: `hptnvme/1.6.22.0` installed for `7.3.0-10-generic` and
  `7.3.0-9-generic`.

## Verified state on the array root

- **xfs healthy.** `xfs_repair` was run on `hptblock6n0p2`; it now mounts with
  `Mounting V5 Filesystem 2c207cb7… → Ending clean mount` and no corruption
  reports in `dmesg`.
- `blacklist nvme` installed at `/etc/modprobe.d/hptnvme-blacklist.conf`
  (it was missing there — the array could not have assembled its own root).
- Patched source at `/usr/src/hptnvme-1.6.22.0`, dkms.conf without
  `AUTOINSTALL` and with per-kernel `KERNELDIR` (see below).
- **Now on Ubuntu 26.10 (stonking)**, upgraded from 26.04.1 — see the upgrade
  section below. GRUB boots `7.3.0-10-generic` (the same kernel as the SATA
  host), with `7.0.0-15` and `7.0.0-14` retained as fallback entries.
- The 6.x kernels were purged earlier: `linux-image-6.14.0-34/35/36/37-generic`
  and `linux-image-6.17.0-22-generic` plus their 10 header packages, the
  orphaned `/lib/modules/6.*` trees, and the vendor `.hpt.<timestamp>` initrd
  backups. The 7.0.0-42 header-only set was purged during the upgrade for the
  same reason (no `linux-image` exists for it).
- dkms: `hptnvme` and `nvidia` 615.71.09 for **all three** kernels
  (`7.0.0-14`, `7.0.0-15`, `7.3.0-10`), each `.ko` in
  `/lib/modules/<kver>/updates/dkms/` with matching vermagic.
- Every bootable initrd contains both `hptnvme.ko` and
  `hptnvme-blacklist.conf` (verified with `lsinitramfs`), and
  `/etc/initramfs-tools/modules` still lists `hptnvme` at line 12.
- `dpkg --audit` is clean and no package is half-configured.
- `/etc/initramfs-tools/modules` lists `hptnvme`; every bootable kernel's
  initrd contains both `hptnvme.ko.zst` and `hptnvme-blacklist.conf`
  (verified with `lsinitramfs` for 7.0.0-15/14, 6.17.0-22, 6.14.0-34..37).
## Upgrading the array root (26.04 LTS → 26.10) — what it took

`do-release-upgrade` **will not offer 26.10**: the meta-release for `resolute`
carries no `UpgradeTo` field and there is no 26.10 entry at all, so it reports
"No new release found" even with `Prompt=normal`. The 26.10 archive suite
(`stonking`) does exist, so the upgrade was done manually:

1. `Prompt=normal` in `/etc/update-manager/release-upgrades`, then rewrite
   `resolute` → `stonking` in `/etc/apt/sources.list.d/*.sources`.
   Sources backed up to `/var/backups/hpt-pre-2610/`.
2. Two PPAs publish no `stonking` suite and break `apt update` with
   "does not have a Release file": `graphics-drivers` and
   `kubuntu-ppa/backports`. Both were renamed to `.disabled-2610`; nothing
   installed here came from them (nvidia is from the main archive).
3. `apt-get full-upgrade` — 2408 packages. It **fails twice on file
   conflicts** (`projectm-data` vs old `libprojectm2v5`,
   `libplasmaactivities-data` vs old `libplasmaactivities6`), which aborts the
   run mid-unpack. Recovery is `dpkg --force-overwrite --configure -a` then
   `apt-get -y -f install -o Dpkg::Options::=--force-overwrite`, then
   `full-upgrade` again with the same option.
4. `nvidia-dkms-615-open` then fails to configure for the same reason the 6.x
   case did: it builds for every kernel that has **headers**, and the orphaned
   `linux-headers-7.0.0-42-generic` has no image. Purging those two packages
   (and the leftover `/lib/modules/7.0.0-42-generic` tree) lets it configure.
5. **dkms did not build hptnvme for 7.3.0-10 during the upgrade** — it had to be
   built explicitly afterwards:
   `dkms install -m hptnvme -v 1.6.22.0 -k 7.3.0-10-generic`, then
   `update-initramfs -u -k all`. **Always check `dkms status` for the new
   kernel before rebooting into the array.**

Note: run these steps as background jobs. A foreground call that hits a tool
or terminal timeout kills dpkg mid-configure and leaves
"dpkg was interrupted, you must manually run 'dpkg --configure -a'".

## Root cause of the original boot failure (for the record)

At boot the generic in-tree `nvme` driver bound all four member drives during
the **initramfs stage** (`nvme nvme0-3: pci function …` at t≈1.1s) while
`hptnvme` only loaded at t≈25.4s via udev coldplug — both match the same class
alias `pci:v*d*sv*sd*bc01sc08i02*`. The kernel never rebinds a device already in
use, so `hptnvme` got only the HBA function, logged
`Verify controller success` / `probe vbus`, and stalled with no volume. The fix
is `blacklist nvme` in `/etc/modprobe.d/` plus `hptnvme` in the initramfs
module list, in **each** install's image set.

## What the patcher now does differently (and why)

The old script was tied to the kernel it happened to be running on. Three
separate ties, all removed:

1. **`AUTOINSTALL="yes"` in the generated `dkms.conf`** made `dkms add` build
   for `uname -r`. In a chroot that is the *host* kernel, which the target has
   no headers for, so the run died at `dkms add` with
   `Your kernel headers for kernel 7.3.0-10-generic cannot be found`. Removed;
   the script now builds explicitly per kernel and treats `dkms add` as
   best-effort.
2. **The vendor `hpt_source/inc/linux/Makefile.def` defaults `KERNELDIR` to
   `/lib/modules/$(shell uname -r)/build`.** dkms passes `KERNELRELEASE`, but
   that Makefile never used it, so even a per-kernel `dkms build -k` compiled
   against the running kernel's headers (`Can not find autoconf.h … KERNELDIR
   /lib/modules/7.3.0-10-generic/build`). The generated `MAKE=` line now passes
   `KERNELDIR=/lib/modules/${kernelver}/build`.
3. **API patches were chosen from `uname -r`** (`if [ "$KERNEL_MAJOR" -eq 7 ]`).
   The vendor source is now staged **exactly as shipped**, and the two deltas are
   resolved per kernel by the DKMS pre-build hook (`dkms-patch.sh`), which reads
   the headers of the kernel being built and rewrites the signature to match.
   **No version number is compared anywhere** — not `uname -r`, not
   `LINUX_VERSION_CODE` — so one staged tree is valid for any kernel:
   - `hpt_getgeo`: takes `struct block_device *` or `struct gendisk *`, probed
     from `block_device_operations` in that kernel's `blkdev.h`. Note the
     `gendisk` form starts at **7.0**, not 6.11: 6.14 and 6.17 still take
     `block_device`.
   - `hpt_init_request`: `numa_node` is `unsigned int` or `int`, probed from
     `blk_mq_tag_set` in that kernel's `blk-mq.h`.
   The rewrites are symmetric and scoped to the function, so the hook is
   idempotent and safe to run repeatedly. Scoping matters: `disk->private_data`
   also occurs elsewhere in `osm_linux.c`, and an unscoped substitution there
   corrupts unrelated code (`'struct hpt_block' has no member named 'bdev'`).

   **`HPT_ROOT` must point at the DKMS build copy**, not at
   `/usr/src/hptnvme-1.6.22.0/hpt_source`. The vendor makefile compiles the
   sources under `HPT_ROOT`; if that is the pristine `/usr/src` tree, the hook's
   edits (which happen in `/var/lib/dkms/.../build/`) are ignored and only the
   kernels that happen to match the pristine signatures will build. Verified by
   compiling the same tree for 7.3.0-10, 7.0.0-15, 6.17.0-22 and 6.14.0-37.

Also: the DKMS stage now loops over `/lib/modules/*` and builds/installs for
every kernel with headers (`/lib/modules/<kver>/build`), reporting and
continuing on failure instead of dying under `set -e`; the hot-reload prompt is
skipped when the running kernel is not one of the built kernels (always true in
a chroot); `POST_BUILD` was dropped (dkms signs via `kmodsign` itself); and the
vendor Makeself payload is invoked with `DISPLAY` unset, which removes the
`konsole` relaunch and makes non-interactive extraction work.

After rebuilding the initramfs the patcher now runs `update-grub` as well. A
kernel installed since the last `update-grub` has no menu entry, so a freshly
built initramfs would be unreachable. The step is deliberately non-fatal: in a
chroot without `/dev` bind-mounted, `grub-probe` cannot resolve the root device
and `update-grub` fails legitimately.

## Chroot package maintenance — what dpkg needs there

An `aptitude upgrade` inside the chroot failed to configure three packages.
None of it was hptnvme; all of it was the chroot environment:

1. **`/dev` was not mounted**, so `dpkg` could not write its log
   (`Can not write log (Is /dev/pts mounted?)`) and `grub-probe` could not
   resolve the root device (`failed to get canonical path of
   /dev/hptblock6n0p2`). Bind-mount `/dev` and `/dev/pts` before any dpkg work:
   `mount --bind /dev target/dev && mount --bind /dev/pts target/dev/pts`.
   Remember to unmount them before shutting the target down.
2. **`nvidia-dkms-595-open` failed on `linux-headers-6.14.0-27-generic`** with
   nvidia's own `conftest/macros.h: unknown type name 'In'`. That kernel's
   headers were an orphan (its `linux-image` was `deinstall ok config-files`,
   so nothing could ever boot it) but its headers still put 6.14.0-27 in the
   dkms build list, aborting the whole configure. Purging
   `linux-headers-6.14.0-27{,-generic}` fixed it; nvidia 595.99.02 then built
   fine for 6.14.0-34..37, 6.17.0-22 and 7.0.0-14/15/42.
3. **`grub-pc` would have installed a bootloader.** Its postinst calls
   `grub-install` with `grub-pc/install_devices`; that value was empty. Before
   configuring, set
   `grub-pc grub-pc/install_devices_empty boolean true` via
   `debconf-set-selections` so it configures without touching any MBR. Do the
   array's bootloader install deliberately, not as a side effect of apt.

After those three, `dpkg --configure -a` finished with `dpkg --audit` clean.

## Watch out: there are several copies of the patcher

The chroot has its own clone at `~/highpoint-ssd7XXX-patcher`
(= `target/home/chazz/highpoint-ssd7XXX-patcher`) and the global symlink
`/usr/local/bin/hpt_modern_patcher` inside the chroot points at it. Editing the
repo copy on the SATA root does **not** update it. A stale old copy was run
inside the chroot, and its first DKMS step (`dkms remove --all`) wiped every
hptnvme build and left the 7.0.0-15 initrd without the module — the array root
went back to being unbootable. If hptnvme suddenly reports only
`hptnvme/1.6.22.0: added`, that is what happened; rebuild with the loop above
and re-run `update-initramfs -u -k all`.

## Next steps — `[HBA REQUIRED]`

- [ ] Boot the array root: GRUB entry `Kubuntu GNU/Linux` → 7.3.0-10-generic
      (already on the cmdline: `root=UUID=2c207cb7… modprobe.blacklist=nvme`).
      Expect `probe controller` for `[05]`–`[08]` and root mounting from
      `hptblock…p2`.
- [ ] Root-on-array cleanup once it boots: confirm the initrd's hptnvme loads
      before `nvme` can bind, and consider dropping the now-redundant
      `modprobe.blacklist=nvme` kernel parameter only if `/etc/modprobe.d`
      proves sufficient.
- [ ] If aptitude still has an interrupted `nvidia-dkms`/kernel configure step,
      finish it inside the chroot; its kernel triggers will re-run
      `update-initramfs`, which is fine — `hptnvme` stays in the images because
      dkms has it installed for every kernel and it is listed in
      `/etc/initramfs-tools/modules`.

## Quirks worth remembering

- **Inside a chroot, `uname -r` is the host kernel.** Anything that consults it
  while installing to a mounted target is wrong. This bit the patcher three
  times (see above).
- The vendor `.bin` is a Makeself archive: with stdin not a TTY *and* `DISPLAY`
  set, it relaunches via `konsole -title … -e $0 --xwin "--noexec --target DIR"`
  — the flags collapse into one argument and extraction silently no-ops. Run it
  with `env -u DISPLAY` (proven to work with stdin from `/dev/null`).
- Piped answers to the patcher's prompts are consumed before the prompts appear;
  a lost answer makes `read` hit EOF, and `set -e` then exits *before* the DKMS
  branch — a silent no-op. Drive prompts with a PTY or pattern matching.
- `dmesg` is restricted for non-root here → `sudo dmesg`. `/boot` images are
  mode 600 → `lsinitramfs` needs sudo.
- The patcher's own `sudo chown root:root` on the global symlink target has left
  the tracked script root-owned before; take ownership back to edit it.
