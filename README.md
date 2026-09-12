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
   git clone https://github.com
   cd highpoint-ssd7505-patcher
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
########## Fuck You Highpoint ##########
---

## Technical Architecture Matrix
* **Target OpenSource Portal Boundary Link:** `https://www.highpoint-tech.com/disclaimer/ssd7000-linux-opensource-driver`
* **Local System Workspace Anchor Path:** `/usr/src/hptnvme-1.6.22.0/`
