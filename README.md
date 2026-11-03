# HighPoint NVMe SSD7505 Adaptive Linux Driver Patcher

An automated, cross-generation out-of-tree kernel deployment utility for the HighPoint SSD7505 controller. This tool dynamically diagnoses the system kernel environment baseline and automatically refactors unmaintained vendor source trees to ensure flawless compilation on modern Linux architectures.

## Key Features
* **Kernel-Version-Agnostic Patching:** The vendor tree is staged exactly as shipped. Each kernel API difference is resolved at build time by the DKMS pre-build hook, which reads *that kernel's own headers* and rewrites the affected signature accordingly. No version numbers are compared anywhere — not `uname -r`, not `LINUX_VERSION_CODE` — so one staged tree builds for 6.14, 6.17, 7.0 and 7.3 alike, including inside a chroot whose kernel is not the running one.
* **Flexible Initialization & Bootstrap:** Self-symlinks globally on its very first run regardless of deployment method (`git clone`, ZIP archive extraction, or raw text copy-paste).
* **Deep Recursive Search Sweep:** Scans the user's entire home tree (`$HOME`) non-recursively for hidden paths to discover and stage vendor driver assets wherever they are saved (including active cloud mounts like Google Drive).
* **DKMS Matrix & Secure Boot Integration:** Builds and installs for every kernel present in `/lib/modules` (skipping any without headers), preventing driver loss on downstream kernel upgrades, and signs out-of-tree binaries using local Machine Owner Keys (`kmodsign`).
* **Live Memory Insertion:** Clears active block-layer structures, hot-unloads old driver definitions, and hooks the newly compiled payload live into the running system kernel storage map.
* **Hot-Reload Safety Interlock:** Refuses that in-place unload/reload whenever any HighPoint array volume is mounted, so a host that boots *from* the array can never lose its live root filesystem to an `rmmod`.

---

## Standard Installation

1. Acquire the source repository structure on your machine:
   ```bash
   git clone https://github.com/kubuntugamer/highpoint-ssd7XXX-patcher.git
   cd highpoint-ssd7XXX-patcher
   ```
2. Execute the patcher utility natively:
   ```bash
   chmod +x hpt_modern_patcher.sh && ./hpt_modern_patcher.sh
   ```
3. Once initialized, the utility registers itself system-wide. For any future kernel shifts, run the command globally from **any directory folder context**:
   ```bash
   hpt_modern_patcher
   ```

---

## Live USB Storage Provisioning & OS Installation Guide

If you are booting from a temporary Live Linux USB environment to install your operating system directly onto a HighPoint NVMe RAID array, you must perform a **two-phase deployment loop** to ensure the target machine remains bootable.

### Phase 1: Unlocking the Array in the Live Environment
1. Boot your Live USB installer and open a terminal window.
2. Clone or text-copy this script onto the live media, make it executable, and run it:
   ```bash
   chmod +x hpt_modern_patcher.sh && ./hpt_modern_patcher.sh
   ```
3. Complete the prompt sequence. Your HighPoint RAID block devices will instantly register and mount live inside the storage installer pool interface.
4. Run your operating system installation to completion target devices. **CRITICAL: Do not click the prompt to restart the machine when the installer finishes.**

### Phase 2: Securely Patching the Newly Installed Target System (Chroot Handoff)
Before rebooting, you must inject and compile the patched driver tree into the freshly installed hard drive operating system's `initramfs`. If you skip this step, the machine will plunge into a black screen GRUB kernel panic on its first boot.

1. Keep your terminal open inside the active Live USB workspace context.
2. Determine your newly installed target system root partition partition and mount it (adjust drive layout letters like `sda2` or `nvme0n1p2` to match your actual hard drive configuration maps):
   ```bash
   sudo mount /dev/target_root_partition /mnt
   for dir in /dev /dev/pts /proc /sys /run; do sudo mount --bind dir /mntdir; done
   ```
3. Seamlessly transfer your command shell scope into the new hard drive system environment root paths via `chroot`:
   ```bash
   sudo chroot /mnt
   ```
4. Execute the patcher utility once more **inside the chroot terminal boundaries** to compile and bake the patched driver storage layers permanently into your storage array's native kernel space:
   ```bash
   hpt_modern_patcher
   ```
5. Safe-exit the root matrix, clean out tracking hooks, and safely cycle machine power limits:
   ```bash
   exit
   sudo umount -R /mnt
   sudo reboot
   ```

---

## Kernel Compatibility

The driver touches two block-layer callbacks whose signatures changed between kernels. The patcher does **not** compare version numbers: when dkms builds for a kernel, a pre-build hook reads *that kernel's own headers* and rewrites the signatures to match. Any kernel whose headers fall into one of the two columns below therefore builds, including kernels released after this table was written.

| What differs | Older form | Newer form | Decided by reading |
|---|---|---|---|
| `block_device_operations.getgeo()` first argument | `struct block_device *` | `struct gendisk *` | `include/linux/blkdev.h` |
| `blk_mq_tag_set.init_request()` `numa_node` argument | `unsigned int` | `int` | `include/linux/blk-mq.h` |

### Verified

Every kernel below was compiled from the same staged vendor tree, with the signature pair the hook selected from that kernel's headers.

| Kernel | Distribution | `getgeo` | `numa_node` | Evidence |
|---|---|---|---|---|
| `6.14.0-34` / `-35` / `-36` / `-37`-generic | Ubuntu 26.04 LTS | `block_device` | `unsigned int` | dkms build + install |
| `6.17.0-22-generic` | Ubuntu 26.04 LTS | `block_device` | `unsigned int` | dkms build + install |
| `7.0.0-14-generic` | Ubuntu 26.04 LTS | `gendisk` | `unsigned int` | dkms build + install, module in initramfs |
| `7.0.0-15-generic` | Ubuntu 26.04 LTS | `gendisk` | `unsigned int` | dkms build + install, module in initramfs, was GRUB default on the array install |
| `7.0.0-42-generic` | Ubuntu 26.04 LTS | `gendisk` | `unsigned int` | compiled (headers only — no kernel image) |
| `7.3.0-10-generic` | Ubuntu 26.10 | `gendisk` | `int` | driver running in production; built and installed for a second host |

Tested with dkms 3.2.2, building against a HighPoint SSD7505 RAID-0 (`1103:7505`, 4x Phison E12 members).

### Expected to work, but not verified here

These share one of the two verified signature pairs, so they should build; they were never actually compiled because the headers were not installed:

- **Liquorix** `6.15.9`, `6.16.4`, `6.17.4`, `6.18.6` (`block_device` + `unsigned int`)
- **Ubuntu 25.10** (`questing`, 6.17 family — the `6.17.0-22` row above is the same ABI)
- Any `7.1`, `7.2`, `7.4`+ kernel: `7.0` and `7.3` bracket them, but neither was built
- Any distribution kernel at `6.14`–`6.19` or `7.0`–`7.3`, provided matching `linux-headers` are installed

### Not covered

- **Kernels below 6.14** were never built (the 6.x rows start at 6.14; older kernels may have further API drift).
- Kernels are only built where headers exist. The patcher skips any kernel in `/lib/modules` without a matching `linux-headers` package and says so, rather than failing the run.

### If a future kernel fails

Symptom — a hard error, not a warning, because GCC 14 treats it as one:

```
error: initialization of 'int (*)(struct gendisk *, struct hd_geometry *)' from
incompatible pointer type 'int (*)(struct block_device *, struct hd_geometry *)'
```

Add another header probe and rewrite pair to the generated `dkms-patch.sh` (see the `getgeo` block for the pattern). Probe the header, never a version number — that is what keeps one staged tree valid for every kernel on the machine.

## Verified Diagnostics

Captured on a live test host after the DKMS path fix (issue #1), proving the patcher stages, patches, builds,
installs and runs the driver end-to-end.

**Host:** Dell OptiPlex 3020, BIOS A20, kernel `7.3.0-10-generic`, dkms 3.2.2, no EFI variables / no Secure Boot.
**Hardware:** HighPoint SSD7505 (PCI `1103:7505`) + 4x 4TB Sabrent Rocket Q (Phison E12) behind the onboard
PLX switch, configured as a bootable RAID-0.

### 1. Build and install

```
$ dkms status
hptnvme/1.6.22.0, 7.3.0-10-generic, x86_64: installed

$ sudo dkms build -m hptnvme -v 1.6.22.0 -k 7.3.0-10-generic
Running the pre_build script... done.
Building module(s)..... done.
Signing module /var/lib/dkms/hptnvme/1.6.22.0/build/hpt_source/product/hptnvme/linux/hptnvme.ko

$ modinfo hptnvme | grep -E '^(filename|version|license)'
filename:       /lib/modules/7.3.0-10-generic/updates/dkms/hptnvme.ko.zst
version:        1.6.22.0
license:        Proprietary
```

The `.ko` lands in `hpt_source/product/hptnvme/linux/` (not `.build/`), which is what the corrected
`BUILT_MODULE_LOCATION` points at.

### 2. Module load and controller probe

```
$ sudo modprobe hptnvme
hptnvme: HighPoint NVMe RAID controller driver (G5) v1.6.22.0 block major fb
hptnvme: [01      ] Verify controller success (retry:0).
scsi host8: hptnvme
hptnvme: [        ] probe vbus
```

> **Critical binding detail:** the four member drives must belong to `hptnvme`, not the generic `nvme`
> driver. The module registers a class-wide alias (`pci:v*d*sv*sd*bc01sc08i02*`) and will claim every NVMe
> endpoint, but the kernel never rebinds a device that is already in use. With only the HBA function
> (`0b:00.0`) bound, the driver logs `probe vbus` and stalls with no volume. Releasing the members makes it
> assemble the set immediately:
>
> ```
> echo 0000:05:00.0 | sudo tee /sys/bus/pci/drivers/nvme/unbind
> echo 0000:05:00.0 | sudo tee /sys/bus/pci/drivers/hptnvme/bind
> # ...repeat for 06:00.0, 07:00.0, 08:00.0
> ```

### 3. Array assembled and visible

```
hptnvme: [05      ] probe controller
hptnvme: [06      ] probe controller
hptnvme: [07      ] probe controller
hptnvme: [08      ] probe controller
hptnvme: [08      ] HBA is probing (state: 0)

$ lsblk -o NAME,SIZE,TYPE,FSTYPE
NAME              SIZE TYPE FSTYPE
hptblock8n0p     14.6T disk
├─hptblock8n0p1   300M part vfat      # ESP
└─hptblock8n0p2  14.6T part xfs       # LABEL=kubuntu_2404

$ sudo blkid /dev/hptblock8n0p2
/dev/hptblock8n0p2: LABEL="kubuntu_2404" UUID="2c207cb7-1be6-43d2-8592-ed30457e2b13" TYPE="xfs"
```

4x 4TB in RAID-0 → 14.6 TiB visible with the original ESP and root volume intact.

### 4. Secure Boot note

On hosts without EFI variables the MOK key cannot be enrolled into the keyring, so the kernel prints
`module verification failed: signature and/or required key missing` and taints (`P`=proprietary, `O`=OOT,
`E`=unsigned). The module still loads; on a UEFI + Secure Boot host the module is signed during install by
dkms itself through `kmodsign` with the MOK, so enrolling that key (`mokutil --import`) is what makes the
signature actually verify.

### 5. Clean unload

`sudo modprobe -r hptnvme` returns 0, releases `0b:00.0`, and re-releasing the members back to `nvme`
restores `nvme0n1`–`nvme3n1` untouched.

### 6. Full end-to-end patcher run (post-fix)

A clean re-run of the utility itself — the exact invocation that previously died at the DKMS step with
`make: *** product/hptnvme/linux: No such file or directory` (issue #1) — now completes every stage without
manual intervention:

```
$ ./hpt_modern_patcher.sh
========================================================================
    HighPoint SSD7505 Linux Multi-Kernel Adaptive Deployment Tool
========================================================================
Detected Kernel Branch: Linux 7.x
-> Staging discovered driver payload from: .../HighPoint_NVMe_G5_Linux_Src_v1.6.22.0_2025_11_10.tar.gz
-> Unpacking compressed source archive payload...
Verifying archive integrity... All good.
-> Staging vendor sources (kernel API adaptation happens per kernel at build time)...
Success! The driver tree is acquired, extracted, patched, and optimized.

Would you like to instantly compile and install this driver into your running kernel via DKMS? (y/N): y
-> Registering framework parameters to system DKMS matrix...
Deleting module hptnvme/1.6.22.0 completely from the DKMS tree.
Creating symlink /var/lib/dkms/hptnvme/1.6.22.0/source -> /usr/src/hptnvme-1.6.22.0
Running the pre_build script... done.
Building module(s)...... done.
Signing module /var/lib/dkms/hptnvme/1.6.22.0/build/hpt_source/product/hptnvme/linux/hptnvme.ko
Installing /lib/modules/7.3.0-10-generic/updates/dkms/hptnvme.ko.zst
Running depmod... done.
-> Module compilation complete.

Would you like to hot-reload the running system driver into memory right now? (y/N): y
insmod /lib/modules/7.3.0-10-generic/updates/dkms/hptnvme.ko.zst
========================================================================
SUCCESS: The modernized driver is compiled, registered, and LIVE in memory!
========================================================================
[ 5829.185716] hptnvme: [05      ] probe controller
[ 5829.195834] hptnvme: [06      ] probe controller
[ 5829.206803] hptnvme: [07      ] probe controller
[ 5829.216874] hptnvme: [08      ] probe controller
```

What this proves, stage by stage:

| Stage | Evidence in the output |
|---|---|
| Deep recursive payload discovery | `Staging discovered driver payload from: ...tar.gz` |
| Nested makeself extraction | `Verifying archive integrity... All good.` |
| Kernel-API patching | `Staging vendor sources (kernel API adaptation happens per kernel at build time)...` — each kernel's headers decide its own signature |
| DKMS registration | symlink created, `pre_build` + `Building module(s)...... done` |
| Correct build output path | `.../build/hpt_source/product/hptnvme/linux/hptnvme.ko` (the `hpt_source/` prefix from the fix) |
| Module signing | `Signing module ...` via `kmodsign` + MOK |
| Install | `updates/dkms/hptnvme.ko.zst` + `Running depmod... done`, repeated per installed kernel |
| Initramfs | `-> Rebuilding kernel images for all installed kernels...` |
| Boot menu | `-> Regenerating GRUB boot menu...` → `-> GRUB boot menu regenerated.` |
| Live load | `insmod ...` then `[05]–[08] probe controller` — all four member drives picked up by the driver |

The last four `probe controller` lines are the definitive signal that the driver owns the members and is
assembling the RAID-0; if they are absent after a hot-reload, the generic `nvme` driver still holds the
endpoints (see the binding note in section 2).

One cosmetic warning appears in every run and is harmless: `module verification failed ... - tainting
kernel` (no EFI/Secure Boot on this host, so the MOK key is not in the keyring).

With multiple kernels installed the DKMS stage now builds and installs one module per kernel in
`/lib/modules`, skipping any kernel without matching headers, so the non-running kernel stays bootable:

```
-> Building module for kernel 7.3.0-10-generic...
-> Kernel 7.3.0-10-generic complete.
-> Building module for kernel 7.3.0-9-generic...
-> Kernel 7.3.0-9-generic complete.
-> Rebuilding kernel images for all installed kernels...
```

A kernel whose build fails is reported (`[!] Build failed for <kver>`) without aborting the run.

---

## Hot-Reload Safety

When root lives on the HighPoint array, the optional "hot-reload the running system driver" step is the one
operation that can destroy the machine: `rmmod hptnvme` removes the block device backing a mounted
filesystem, and on such a host that filesystem is `/`.

The script therefore probes the mount table through `array_holds_live_mounts()` before unloading anything and
refuses when a mounted volume resolves to a `/dev/hptblock*` source:

```bash
if [[ "$LOAD_CHOICE" =~ ^[Yy]$ ]] && array_holds_live_mounts; then
    echo "[!] Refusing to hot-reload: a HighPoint array volume is mounted, ..."
    LOAD_CHOICE="n"
fi
```

Build, install and initramfs rebuild all still run; only the in-place unload is skipped, and a reboot picks up
the newly installed module. On a host whose root is on another disk and whose array volumes are all
unmounted, the interlock passes and hot-reload behaves as before. The generated `dkms.conf` also sets
`AUTOINSTALL="yes"` — without it dkms skips newly installed kernels, and a kernel without `hptnvme` cannot
boot a machine whose root is on the array.

---

## Technical Architecture Matrix
* **Target OpenSource Portal Boundary Link:** `https://www.highpoint-tech.com/disclaimer/ssd7000-linux-opensource-driver`
* **Local System Workspace Anchor Path:** `/usr/src/hptnvme-1.6.22.0/`
