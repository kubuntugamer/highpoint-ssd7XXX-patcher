# HighPoint NVMe SSD7505 Adaptive Linux Driver Patcher

An automated, cross-generation out-of-tree kernel deployment utility for the HighPoint SSD7505 controller. This tool dynamically diagnoses the system kernel environment baseline and automatically refactors unmaintained vendor source trees to ensure flawless compilation on modern Linux architectures.

## Key Features
* **Multi-Kernel Branch Adaptation:** Automatically detects running kernel major releases, applying block-layer pointer translations (`struct gendisk *disk`) for modern Linux 7.x (Ubuntu 26.04 / Liquorix) while preserving native legacy geometry code lines for Linux 6.x branches (Ubuntu 25.10).
* **Flexible Initialization & Bootstrap:** Self-symlinks globally on its very first run regardless of deployment method (`git clone`, ZIP archive extraction, or raw text copy-paste).
* **Deep Recursive Search Sweep:** Scans the user's entire home tree (`$HOME`) non-recursively for hidden paths to discover and stage vendor driver assets wherever they are saved (including active cloud mounts like Google Drive).
* **DKMS Matrix & Secure Boot Integration:** Automates module registration to prevent driver loss on downstream kernel upgrades, signing out-of-tree binaries using local Machine Owner Keys (`kmodsign`).
* **Live Memory Insertion:** Clears active block-layer structures, hot-unloads old driver definitions, and hooks the newly compiled payload live into the running system kernel storage map.

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
`E`=unsigned). The module still loads; on a UEFI + Secure Boot host the `POST_BUILD` sign-file step in
`dkms.conf` (and `mokutil --import`) is what makes the signature actually verify.

### 5. Clean unload

`sudo modprobe -r hptnvme` returns 0, releases `0b:00.0`, and re-releasing the members back to `nvme`
restores `nvme0n1`–`nvme3n1` untouched.

---

## Technical Architecture Matrix
* **Target OpenSource Portal Boundary Link:** `https://www.highpoint-tech.com/disclaimer/ssd7000-linux-opensource-driver`
* **Local System Workspace Anchor Path:** `/usr/src/hptnvme-1.6.22.0/`
