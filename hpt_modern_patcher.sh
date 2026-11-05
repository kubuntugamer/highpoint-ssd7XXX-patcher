#!/bin/bash
# -------------------------------------------------------------------------
# HighPoint SSD7505 Linux Multi-Kernel Build & Deployment Wizard
# Multi-Format / Comprehensive Deep Recursive Home Space Scan
# -------------------------------------------------------------------------
set -e

# Define system path shortcuts dynamically based on script location
GLOBAL_LINK_PATH="/usr/local/bin/hpt_modern_patcher"
CURRENT_SCRIPT_SOURCE="$(readlink -f "${BASH_SOURCE}")"

# 1. Professional Git Clone Bootstrap Engine (Ensures global calling context)
if [ ! -L "$GLOBAL_LINK_PATH" ] || [ "$(readlink "$GLOBAL_LINK_PATH")" != "$CURRENT_SCRIPT_SOURCE" ]; then
    echo "========================================================================"
    echo "    First-Time Execution: System-Wide Symlink Engine Initializing..."
    echo "========================================================================"
    echo "-> Detected fresh clone deployment. Mapping shortcut to this repo folder..."
    echo "-> Target Source: $CURRENT_SCRIPT_SOURCE"
    echo ""
    
    # Securely drop old messy binaries or dead shortcut pointers first
    sudo rm -f "$GLOBAL_LINK_PATH"
    
    # Establish a flawless, non-duplicating absolute system shortcut link pointing back here
    sudo ln -sf "$CURRENT_SCRIPT_SOURCE" "$GLOBAL_LINK_PATH"
    sudo chown root:root "$GLOBAL_LINK_PATH" 2>/dev/null || true
    
    echo "SUCCESS: Global shortcut successfully mapped to: $GLOBAL_LINK_PATH"
    echo "-> Handing over active execution to the global system-wide instance..."
    echo "------------------------------------------------------------------------"
    echo ""
    
    # Re-execute using the newly built global command path, dropping relative tracking issues
    exec "$GLOBAL_LINK_PATH" "$@"
fi

# Everything below runs natively out of your pristine cloned repository directory context
REPO_ROOT_DIR="$( cd "$( dirname "$CURRENT_SCRIPT_SOURCE" )" && pwd )"
DKMS_SOURCE_DIR="/usr/src/hptnvme-1.6.22.0"
BIN_FILE="hptnvme_g5_linux_src_v1.6.22.0_2025_11_10.bin"
TAR_FILE="HighPoint_NVMe_G5_Linux_Src_v1.6.22.0_2025_11_10.tar.gz"

PORTAL_URL="https://www.highpoint-tech.com/disclaimer/ssd7000-linux-opensource-driver"
FINAL_SOURCE_DIR="$DKMS_SOURCE_DIR/hpt_source"
SCRATCH_DIR="$DKMS_SOURCE_DIR/hpt_archive_scratch"

sudo mkdir -p "$DKMS_SOURCE_DIR"

# Target original non-root user details to target real home folder roots
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# Is any HighPoint array volume mounted right now? Every mounted volume on the
# array is backed by the module currently in memory, so unloading the driver takes
# that volume down with it - mid-write when it is the live root filesystem.
array_holds_live_mounts() {
    local sources
    sources="$(findmnt -nro SOURCE 2>/dev/null || true)"
    if [ -z "$sources" ]; then
        sources="$(awk '{print $1}' /proc/mounts 2>/dev/null || true)"
    fi
    if printf '%s\n' "$sources" | grep -qE '^/dev/hptblock'; then
        return 0
    fi
    return 1
}

# 2. Comprehensive Deep Recursive Scan Routine across all files and folders in $REAL_HOME
find_staged_file_recursive() {
    find "$REAL_HOME" -type d \( -name ".*" -o -name "snap" \) -prune -o -type f \( -name "$TAR_FILE" -o -name "$BIN_FILE" \) -print 2>/dev/null | while read -r candidate; do
        if [[ "$candidate" == *"$TAR_FILE" ]]; then
            echo "$candidate"
            return 0
        elif [[ "$candidate" == *"$BIN_FILE" ]]; then
            if ! head -n 5 "$candidate" | grep -qi "DOCTYPE html"; then
                echo "$candidate"
                return 0
            fi
        fi
    done
}

# -------------------------------------------------------------------------
# Build prerequisites.
# A Live USB session boots a kernel but ships no compiler, no dkms and no
# headers, so dkms has nothing to build against and the run dies at the first
# build. This installs whatever is missing using the package manager of the
# distribution that is actually running -- the live media itself, or a target
# system reached through chroot.
# -------------------------------------------------------------------------
PKG_MGR=""
APT_REFRESH_DONE=0

detect_pkg_mgr() {
    if command -v apt-get >/dev/null 2>&1; then PKG_MGR="apt"
    elif command -v dnf >/dev/null 2>&1; then PKG_MGR="dnf"
    elif command -v yum >/dev/null 2>&1; then PKG_MGR="yum"
    elif command -v pacman >/dev/null 2>&1; then PKG_MGR="pacman"
    elif command -v zypper >/dev/null 2>&1; then PKG_MGR="zypper"
    else PKG_MGR=""
    fi
}

# Package that provides /lib/modules/<release>/build, per distribution.
kernel_headers_pkg() {
    [ -n "$PKG_MGR" ] || detect_pkg_mgr
    case "$PKG_MGR" in
        apt)     echo "linux-headers-$1" ;;
        dnf|yum) echo "kernel-devel-$1" ;;
        zypper)  echo "kernel-devel-$1" ;;
        pacman)  echo "linux-headers" ;;
    esac
}

pkg_install() {
    [ -n "$PKG_MGR" ] || detect_pkg_mgr
    case "$PKG_MGR" in
        apt)
            # Live media ships empty apt lists, so an install without a refresh
            # fails with "Unable to locate package". Refresh once per run.
            if [ "$APT_REFRESH_DONE" = 0 ]; then
                APT_REFRESH_DONE=1
                if ! ls /var/lib/apt/lists/ 2>/dev/null | grep -q 'Packages'; then
                    echo "-> Refreshing package metadata (live media boots with empty apt lists)..."
                    if ! sudo apt-get update; then
                        echo "[!] apt-get update failed - no network, or this live media's sources are unusable."
                        return 1
                    fi
                fi
            fi
            sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
            ;;
        dnf|yum) sudo "$PKG_MGR" install -y "$@" ;;
        pacman)  sudo pacman -Sy --noconfirm "$@" ;;
        zypper)  sudo zypper --non-interactive install "$@" ;;
        *) return 1 ;;
    esac
}

# Make one kernel buildable, installing its headers if they are absent.
ensure_kernel_headers() {
    local kver="$1" hdr
    [ -e "/lib/modules/$kver/build" ] && return 0
    # pacman has a single unversioned linux-headers package, so it can only
    # install headers for the kernel that is running right now.
    if [ "$PKG_MGR" = "pacman" ] && [ "$kver" != "$(uname -r)" ]; then
        return 1
    fi
    hdr="$(kernel_headers_pkg "$kver")"
    [ -n "$hdr" ] || return 1
    echo "-> Missing headers for $kver - installing $hdr..."
    pkg_install "$hdr" || echo "[!] Could not install $hdr."
    [ -e "/lib/modules/$kver/build" ]
}

ensure_build_prerequisites() {
    local kver hdr pkgs=()
    kver="$(uname -r)"

    if command -v gcc >/dev/null 2>&1 && command -v make >/dev/null 2>&1 \
        && command -v dkms >/dev/null 2>&1 && [ -e "/lib/modules/$kver/build" ]; then
        echo "-> Build prerequisites already present (gcc, make, dkms, headers for $kver)."
        return 0
    fi

    echo "------------------------------------------------------------------------"
    echo "[!] Building the driver needs a compiler, dkms and the headers of the"
    echo "    kernel it is built for. Installing whatever is missing..."
    echo "------------------------------------------------------------------------"

    detect_pkg_mgr
    if [ -z "$PKG_MGR" ]; then
        echo "[!] No supported package manager found (apt, dnf, yum, pacman, zypper)."
        return 1
    fi

    if ! command -v gcc >/dev/null 2>&1 || ! command -v make >/dev/null 2>&1; then
        case "$PKG_MGR" in
            apt)    pkgs+=(build-essential) ;;
            pacman) pkgs+=(base-devel) ;;
            *)      pkgs+=(gcc make) ;;
        esac
    fi
    command -v dkms >/dev/null 2>&1 || pkgs+=(dkms)

    if [ ${#pkgs[@]} -gt 0 ]; then
        echo "-> Installing build toolchain: ${pkgs[*]}"
        pkg_install "${pkgs[@]}" || echo "[!] Installing ${pkgs[*]} failed - the header step below decides the outcome."
    fi

    if [ ! -e "/lib/modules/$kver/build" ]; then
        hdr="$(kernel_headers_pkg "$kver")"
        echo "-> Installing kernel headers: $hdr"
        if pkg_install "$hdr" && [ -e "/lib/modules/$kver/build" ]; then
            echo "-> Headers for $kver installed."
            return 0
        fi
        echo "[!] Could not install headers for the running kernel ($kver)."
        echo "    A live ISO kernel is not always published as a headers package."
        echo "    The driver tree stays staged in $DKMS_SOURCE_DIR - compile it from"
        echo "    the installed system, or from its chroot, where headers exist."
        return 1
    fi

    echo "-> Headers for $kver are present."
    return 0
}

echo "========================================================================"
echo "    HighPoint SSD7505 Linux Multi-Kernel Adaptive Deployment Tool"
echo "========================================================================"
echo "Command Path: $GLOBAL_LINK_PATH"
echo "Source Repository: $REPO_ROOT_DIR"
echo "System Workspace: $DKMS_SOURCE_DIR"
echo "Running Kernel: $(uname -r) (informational only - every kernel in /lib/modules is built)"
echo ""

# Run deep sweep pass 1
STAGED_PATH=$(find_staged_file_recursive | head -n 1 || echo "")

# 3. Post-Download Discovery Interface Switch
if [ -z "$STAGED_PATH" ]; then
    echo "[!] No local HighPoint installer package discovered anywhere inside $REAL_HOME"
    echo "------------------------------------------------------------------------"
    echo "Due to HighPoint's Software License Agreement restrictions and browser-"
    echo "session firewall gates, you must manually acquire the source driver."
    echo "------------------------------------------------------------------------"
    echo ""
    echo "-> Attempting to launch your web browser to open the download portal..."
    
    if [ -n "$SUDO_USER" ]; then
        sudo -u "$SUDO_USER" xdg-open "$PORTAL_URL" 2>/dev/null || sudo -u "$SUDO_USER" open "$PORTAL_URL" 2>/dev/null || true
    else
        if command -v xdg-open >/dev/null 2>&1; then xdg-open "$PORTAL_URL"
        elif command -v open >/dev/null 2>&1; then open "$PORTAL_URL"
        fi
    fi

    echo ""
    echo "Step 1: On the web page that just opened, scroll to the bottom,"
    echo "        check the 'Accept' terms box, and click the Download link."
    echo "        Link: $PORTAL_URL"
    echo ""
    echo "Step 2: Save or move either the downloaded file ('$TAR_FILE' or '$BIN_FILE')"
    echo "        into ANY file path or folder anywhere inside your home tree ($REAL_HOME)."
    echo ""
    read -p "Press [Enter] once the download completes to trigger the deep recursive scan sweep..."
    
    echo "-> Running post-download deep recursive home folder sweep..."
    STAGED_PATH=$(find_staged_file_recursive | head -n 1 || echo "")
fi

if [ -z "$STAGED_PATH" ] || [ ! -f "$STAGED_PATH" ]; then
    echo ""
    echo "[!] Error: Deep search sweep failed. Could not locate driver assets anywhere in $REAL_HOME"
    exit 1
fi

# Cleanly clone package into our locked workspace root
echo "-> Staging discovered driver payload from: $STAGED_PATH"
if [[ "$STAGED_PATH" == *"$TAR_FILE" ]]; then
    sudo cp "$STAGED_PATH" "$DKMS_SOURCE_DIR/$TAR_FILE"
    ACTIVE_FORMAT="TAR"
else
    sudo cp "$STAGED_PATH" "$DKMS_SOURCE_DIR/$BIN_FILE"
    ACTIVE_FORMAT="BIN"
fi

cd "$DKMS_SOURCE_DIR"
sudo rm -rf "$SCRATCH_DIR" "$FINAL_SOURCE_DIR" 2>/dev/null

# 4. Universal Staged Extraction Pass
if [ "$ACTIVE_FORMAT" = "TAR" ]; then
    echo "-> Unpacking compressed source archive payload..."
    sudo mkdir -p "$SCRATCH_DIR"
    sudo rm -rf "$SCRATCH_DIR"/*
    sudo tar -xf "$TAR_FILE" -C "$SCRATCH_DIR"
    
    NESTED_BIN=$(find "$SCRATCH_DIR" -maxdepth 2 -name "$BIN_FILE" | head -n 1)
    if [ -f "$NESTED_BIN" ]; then
        sudo chmod +x "$NESTED_BIN"
        # DISPLAY is dropped on purpose: with DISPLAY set and stdin not a TTY, this
        # Makeself payload relaunches itself through konsole and silently extracts
        # nothing. Without it, --noexec works the same in a terminal or a script.
        sudo env -u DISPLAY "$NESTED_BIN" --noexec --target "$SCRATCH_DIR/extracted"
        TRUE_ROOT=$(find "$SCRATCH_DIR/extracted" -type d -name "osm" -exec dirname {} \; | head -n 1)
        [ -d "$TRUE_ROOT" ] && sudo cp -a "$TRUE_ROOT/." "$FINAL_SOURCE_DIR/" || sudo cp -a "$SCRATCH_DIR/extracted/." "$FINAL_SOURCE_DIR/"
    else
        echo "Error: Embedded package '$BIN_FILE' not found inside the unzipped archive!"
        exit 1
    fi
else
    echo "-> Unpacking raw executable setup payload..."
    sudo mkdir -p "$FINAL_SOURCE_DIR"
    sudo chmod +x "$BIN_FILE"
    sudo env -u DISPLAY ./"$BIN_FILE" --noexec --target "$FINAL_SOURCE_DIR"
fi

OSM_FILE="$FINAL_SOURCE_DIR/osm/linux/osm_linux.c"
MAKE_FILE="$FINAL_SOURCE_DIR/product/hptnvme/linux/Makefile"

if [ ! -f "$OSM_FILE" ] || [ ! -f "$MAKE_FILE" ]; then
    echo "Error: Extraction failed. Core structural wrappers missing!"
    exit 1
fi

# 5. Source tree preparation
# The vendor sources are staged exactly as shipped. Kernel-API adaptation is NOT
# decided here: it is done per kernel at build time by the DKMS pre-build hook,
# which reads the headers of the kernel being built against and rewrites the two
# signatures that differ. No version numbers are compared anywhere, so one staged
# tree is valid for every kernel on the box, and for a chroot target whose kernel
# is not the one running this script.
echo "-> Staging vendor sources (kernel API adaptation happens per kernel at build time)..."

sudo sed -i '/hptnvme-objs/ s/$/ \$(HPT_ROOT)\/lib\/linux\/free-x86_64\/him_nvme.o \$(HPT_ROOT)\/lib\/linux\/free-x86_64\/ldm_raid.o/' "$MAKE_FILE"
sudo sed -i '/hptnvme-y/ s/$/ \$(HPT_ROOT)\/lib\/linux\/free-x86_64\/him_nvme.o \$(HPT_ROOT)\/lib\/linux\/free-x86_64\/ldm_raid.o/' "$MAKE_FILE"
sudo rm -rf "$SCRATCH_DIR" 2>/dev/null || true

echo "------------------------------------------------------------------------"
echo "Success! The driver tree is acquired, extracted, patched, and optimized."
echo "------------------------------------------------------------------------"
echo ""

read -p "Would you like to instantly compile and install this driver into your running kernel via DKMS? (y/N): " INSTALL_CHOICE

if [[ "$INSTALL_CHOICE" =~ ^[Yy]$ ]]; then
    # Live media, and fresh installs reached through chroot, usually have no
    # compiler, no dkms and no kernel headers at all. Without this the run dies
    # in the middle of the DKMS stage instead of saying what is missing.
    if ! ensure_build_prerequisites; then
        echo ""
        echo "[!] Skipping the DKMS stage: this system cannot build the module yet."
        echo "    Re-run the patcher once the packages listed above are installed."
        exit 1
    fi

    echo "-> Registering framework parameters to system DKMS matrix..."
    sudo dkms remove -m hptnvme -v 1.6.22.0 --all 2>/dev/null || true
    
    sudo tee "$DKMS_SOURCE_DIR/dkms-patch.sh" > /dev/null << 'INNER_EOF'
#!/bin/bash
# Runs from the DKMS build tree once per kernel, before make. Every kernel-API
# difference is resolved by reading the headers of the kernel being built for --
# never by comparing version numbers. The rewrites are symmetric, so this is safe
# to run repeatedly and for any mix of kernels.
KSRC="/lib/modules/${kernelver:-$(uname -r)}/build"
OSM="hpt_source/osm/linux/osm_linux.c"

if [ -f "$OSM" ] && [ -d "$KSRC" ]; then
    # block_device_operations.getgeo(): takes struct block_device * on older
    # kernels, struct gendisk * once the block layer passes the disk instead.
    if grep -q 'int (\*getgeo)(struct gendisk' "$KSRC/include/linux/blkdev.h" 2>/dev/null; then
        # scoped to the function body: 'disk->private_data' also appears elsewhere in
        # this file, so an unscoped rewrite corrupts unrelated code.
        sed -i -e '/^static int hpt_getgeo/,/^}/ s|struct block_device \*bdev, struct hd_geometry \*geo|struct gendisk *disk, struct hd_geometry *geo|' \
            -e '/^static int hpt_getgeo/,/^}/ s|get_capacity(bdev->bd_disk)|get_capacity(disk)|' \
            -e '/^static int hpt_getgeo/,/^}/ s|bdev->bd_disk->private_data|disk->private_data|' \
            "$OSM"
    else
        sed -i -e '/^static int hpt_getgeo/,/^}/ s|struct gendisk \*disk, struct hd_geometry \*geo|struct block_device *bdev, struct hd_geometry *geo|' \
            -e '/^static int hpt_getgeo/,/^}/ s|get_capacity(disk)|get_capacity(bdev->bd_disk)|' \
            -e '/^static int hpt_getgeo/,/^}/ s|disk->private_data|bdev->bd_disk->private_data|' \
            "$OSM"
    fi

    # blk_mq_tag_set.init_request(): the numa_node argument is unsigned int on
    # older kernels and int on newer ones. Ask this kernel's own declaration.
    if sed -n '/int (\*init_request)/,+1p' "$KSRC/include/linux/blk-mq.h" 2>/dev/null \
        | tail -n 1 | tr -d ' \t' | grep -qE ',int\);$'; then
        sed -i 's|unsigned int hctx_idx, unsigned int numa_node)|unsigned int hctx_idx, int numa_node)|' "$OSM"
    else
        sed -i 's|unsigned int hctx_idx, int numa_node)|unsigned int hctx_idx, unsigned int numa_node)|' "$OSM"
    fi
fi

TARGET="hpt_source/product/hptnvme/linux/.build/Makefile"
if [ -f "$TARGET" ]; then
    sed -i '/hptnvme-objs/ s/$/ \$(HPT_ROOT)\/lib\/linux\/free-x86_64\/him_nvme.o \$(HPT_ROOT)\/lib\/linux\/free-x86_64\/ldm_raid.o/' "$TARGET"
    sed -i '/hptnvme-y/ s/$/ \$(HPT_ROOT)\/lib\/linux\/free-x86_64\/him_nvme.o \$(HPT_ROOT)\/lib\/linux\/free-x86_64\/ldm_raid.o/' "$TARGET"
fi
INNER_EOF
    sudo chmod +x "$DKMS_SOURCE_DIR/dkms-patch.sh"

    sudo tee "$DKMS_SOURCE_DIR/dkms.conf" > /dev/null << 'INNER_EOF'
PACKAGE_NAME="hptnvme"
PACKAGE_VERSION="1.6.22.0"
CLEAN="make -C hpt_source/product/hptnvme/linux clean"
PRE_BUILD="./dkms-patch.sh"
BUILT_MODULE_NAME="hptnvme"
BUILT_MODULE_LOCATION="hpt_source/product/hptnvme/linux/"
DEST_MODULE_LOCATION="/updates/kernel/drivers/nvme/host/"
# AUTOINSTALL is what makes a newly installed kernel build this module at all:
# dkms 3.x' common.postinst refuses to build a package that does not set it, and
# here the array carries '/', so a kernel without hptnvme cannot boot.
AUTOINSTALL="yes"
# KERNELDIR must be passed explicitly: the vendor Makefile otherwise defaults it to
# /lib/modules/$(uname -r)/build, which is the *running* kernel. That is wrong on
# any multi-kernel box and fatal inside a chroot, where it names the host kernel.
# HPT_ROOT points at the DKMS build copy, not at the /usr/src source tree: that is
# the tree the pre_build hook adapts for this kernel, so the sources it rewrites are
# the sources make actually compiles.
MAKE="make -C hpt_source/product/hptnvme/linux HPT_ROOT=${dkms_tree}/${PACKAGE_NAME}/${PACKAGE_VERSION}/build/hpt_source KERNELDIR=/lib/modules/${kernelver}/build V=1"
INNER_EOF

    # Register the source tree only. 'dkms add' is not told which kernel to use,
    # so it would otherwise fall back to 'uname -r' and try to build for it. That
    # kernel is the running one, which inside a chroot (installing to a disk that
    # is not the host) has no headers and no reason to be built at all.
    sudo dkms add -m hptnvme -v 1.6.22.0 || echo "[!] dkms add reported an error - continuing, the source tree is registered either way."

    # Build for every installed kernel, not just the running one. The
    # 'dkms remove --all' above deleted the builds for the other kernels, so
    # they would otherwise be left with an initramfs that lists hptnvme but no
    # module to load it for them.
    BUILT_KERNELS=""
    for KERNEL_DIR in /lib/modules/*; do
        TARGET_KERNEL="$(basename "$KERNEL_DIR")"
        if [ ! -e "$KERNEL_DIR/build" ] && ! ensure_kernel_headers "$TARGET_KERNEL"; then
            echo "[!] Skipping $TARGET_KERNEL - no kernel headers ($(kernel_headers_pkg "$TARGET_KERNEL"))."
            continue
        fi
        echo "-> Building module for kernel $TARGET_KERNEL..."
        if sudo dkms build -m hptnvme -v 1.6.22.0 -k "$TARGET_KERNEL" \
            && sudo dkms install -m hptnvme -v 1.6.22.0 -k "$TARGET_KERNEL"; then
            echo "-> Kernel $TARGET_KERNEL complete."
            BUILT_KERNELS="$BUILT_KERNELS $TARGET_KERNEL"
        else
            echo "[!] Build failed for $TARGET_KERNEL - that kernel will boot without hptnvme."
        fi
    done

    if [ -z "$BUILT_KERNELS" ]; then
        echo "[!] No kernel was built at all - install the matching linux-headers package(s)."
    fi

    # Rebuild the kernel boot images so the freshly installed module and the
    # modprobe policy are baked into every installed kernel's initramfs.
    if [ -d /etc/initramfs-tools ] && command -v update-initramfs >/dev/null 2>&1; then
        if ! grep -qE '^hptnvme([[:space:]]|$)' /etc/initramfs-tools/modules 2>/dev/null; then
            echo "-> Registering hptnvme in /etc/initramfs-tools/modules for initramfs inclusion..."
            echo "hptnvme" | sudo tee -a /etc/initramfs-tools/modules > /dev/null
        fi
        echo "-> Rebuilding kernel images for all installed kernels..."
        sudo update-initramfs -u -k all
        echo "-> Kernel images rebuilt successfully."
    else
        echo "[!] update-initramfs not available - kernel images were NOT rebuilt."
    fi

    # Regenerate the boot menu as well. A kernel installed since the last
    # update-grub run has no entry, so a freshly built initramfs would be
    # unreachable. Non-fatal on purpose: inside a chroot without /dev mounted,
    # grub-probe cannot resolve the root device and this fails legitimately.
    if command -v update-grub >/dev/null 2>&1; then
        echo "-> Regenerating GRUB boot menu..."
        if sudo update-grub; then
            echo "-> GRUB boot menu regenerated."
        else
            echo "[!] update-grub failed - boot menu was NOT regenerated (in a chroot, check that /dev is mounted)."
        fi
    else
        echo "[!] update-grub not available - boot menu was NOT regenerated."
    fi

    echo "-> Module compilation complete."
    echo ""
    
    read -p "Would you like to hot-reload the running system driver into memory right now? (y/N): " LOAD_CHOICE
    # Hot-reloading only makes sense for the running kernel, and only if it is one
    # of the kernels this run actually built for (it is not, when running inside a
    # chroot against a different installed system).
    if [[ "$LOAD_CHOICE" =~ ^[Yy]$ ]] && [[ " $BUILT_KERNELS " != *" $(uname -r) "* ]]; then
        echo "[!] The running kernel ($(uname -r)) has no module from this run - skipping hot-reload."
        LOAD_CHOICE="n"
    fi
    # A host whose root (or ESP, or data volumes) lives on the array must never
    # hot-reload: rmmod hptnvme yanks the block device out from under a mounted
    # filesystem, which on a boot-from-array system means the running root.
    if [[ "$LOAD_CHOICE" =~ ^[Yy]$ ]] && array_holds_live_mounts; then
        echo "[!] Refusing to hot-reload: a HighPoint array volume is mounted, so this"
        echo "    driver is holding up a live filesystem (on a boot-from-array host that"
        echo "    includes root itself). Unloading it here would take that mount down"
        echo "    mid-write. The module is installed - reboot to load it instead."
        LOAD_CHOICE="n"
    fi
    if [[ "$LOAD_CHOICE" =~ ^[Yy]$ ]]; then
        if lsmod | grep -q "hptnvme"; then sudo rmmod hptnvme; fi
        sudo modprobe -v hptnvme
        echo "========================================================================"
        echo "SUCCESS: The modernized driver is compiled, registered, and LIVE in memory!"
        echo "========================================================================"
        sudo dmesg | grep -i hptnvme | tail -n 4
    fi
fi
