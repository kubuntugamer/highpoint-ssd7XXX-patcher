#!/bin/bash
# -------------------------------------------------------------------------
# HighPoint SSD7505 Linux Multi-Kernel Build & Deployment Wizard
# 100% Legal / Multi-Format / Comprehensive Deep Recursive Home Space Scan
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
REPO_ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )"
DKMS_SOURCE_DIR="/usr/src/hptnvme-1.6.22.0"
BIN_FILE="hptnvme_g5_linux_src_v1.6.22.0_2025_11_10.bin"
TAR_FILE="HighPoint_NVMe_G5_Linux_Src_v1.6.22.0_2025_11_10.tar.gz"

PORTAL_URL="https://www.highpoint-tech.com/disclaimer/ssd7000-linux-opensource-driver"
FINAL_SOURCE_DIR="$DKMS_SOURCE_DIR/hpt_source"
SCRATCH_DIR="$DKMS_SOURCE_DIR/hpt_archive_scratch"
KERNEL_MAJOR=$(uname -r | cut -d. -f1)

sudo mkdir -p "$DKMS_SOURCE_DIR"

# Target original non-root user details to target real home folder roots
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

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

echo "========================================================================"
echo "    HighPoint SSD7505 Linux Multi-Kernel Adaptive Deployment Tool"
echo "========================================================================"
echo "Command Path: $GLOBAL_LINK_PATH"
echo "Source Repository: $REPO_ROOT_DIR"
echo "System Workspace: $DKMS_SOURCE_DIR"
echo "Detected Kernel Branch: Linux ${KERNEL_MAJOR}.x"
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
        sudo "$NESTED_BIN" --noexec --target "$SCRATCH_DIR/extracted"
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
    sudo ./"$BIN_FILE" --noexec --target "$FINAL_SOURCE_DIR"
fi

OSM_FILE="$FINAL_SOURCE_DIR/osm/linux/osm_linux.c"
MAKE_FILE="$FINAL_SOURCE_DIR/product/hptnvme/linux/Makefile"

if [ ! -f "$OSM_FILE" ] || [ ! -f "$MAKE_FILE" ]; then
    echo "Error: Extraction failed. Core structural wrappers missing!"
    exit 1
fi

# 5. Kernel Patch Modification Loop
if [ "$KERNEL_MAJOR" -eq 7 ]; then
    echo "-> Modifying out-of-tree signatures for modern Linux 7.x APIs..."
    sudo sed -i 's/int hpt_getgeo(struct block_device \*bdev, struct hd_geometry \*geo)/int hpt_getgeo(struct gendisk \*disk, struct hd_geometry \*geo)/g' "$OSM_FILE"
    sudo sed -i 's/geo->cylinders = get_capacity(bdev->bd_disk) >> 11;/geo->cylinders = get_capacity(disk) >> 11;/g' "$OSM_FILE"
    sudo sed -i 's/unsigned int hctx_idx, unsigned int numa_node/unsigned int hctx_idx, int numa_node/g' "$OSM_FILE"
else
    echo "-> Step 3: Linux 6.x branch detected. Skipping 7.x structural overrides..."
fi

sudo sed -i '/hptnvme-objs/ s/$/ \$(HPT_ROOT)\/lib\/linux\/free-x86_64\/him_nvme.o \$(HPT_ROOT)\/lib\/linux\/free-x86_64\/ldm_raid.o/' "$MAKE_FILE"
sudo sed -i '/hptnvme-y/ s/$/ \$(HPT_ROOT)\/lib\/linux\/free-x86_64\/him_nvme.o \$(HPT_ROOT)\/lib\/linux\/free-x86_64\/ldm_raid.o/' "$MAKE_FILE"
sudo rm -rf "$SCRATCH_DIR" 2>/dev/null || true

echo "------------------------------------------------------------------------"
echo "Success! The driver tree is acquired, extracted, patched, and optimized."
echo "------------------------------------------------------------------------"
echo ""

read -p "Would you like to instantly compile and install this driver into your running kernel via DKMS? (y/N): " INSTALL_CHOICE

if [[ "$INSTALL_CHOICE" =~ ^[Yy]$ ]]; then
    echo "-> Registering framework parameters to system DKMS matrix..."
    sudo dkms remove -m hptnvme -v 1.6.22.0 --all 2>/dev/null || true
    
    sudo tee "$DKMS_SOURCE_DIR/dkms-patch.sh" > /dev/null << 'INNER_EOF'
#!/bin/bash
TARGET="product/hptnvme/linux/.build/Makefile"
if [ -f "$TARGET" ]; then
    sed -i '/hptnvme-objs/ s/$/ \$(HPT_ROOT)\/lib\/linux\/free-x86_64\/him_nvme.o \$(HPT_ROOT)\/lib\/linux\/free-x86_64\/ldm_raid.o/' "$TARGET"
    sed -i '/hptnvme-y/ s/$/ \$(HPT_ROOT)\/lib\/linux\/free-x86_64\/him_nvme.o \$(HPT_ROOT)\/lib\/linux\/free-x86_64\/ldm_raid.o/' "$TARGET"
fi
INNER_EOF
    sudo chmod +x "$DKMS_SOURCE_DIR/dkms-patch.sh"

    sudo tee "$DKMS_SOURCE_DIR/dkms.conf" > /dev/null << 'INNER_EOF'
PACKAGE_NAME="hptnvme"
PACKAGE_VERSION="1.6.22.0"
CLEAN="make -C product/hptnvme/linux clean"
PRE_BUILD="./dkms-patch.sh"
BUILT_MODULE_NAME="hptnvme"
BUILT_MODULE_LOCATION="product/hptnvme/linux/.build/"
DEST_MODULE_LOCATION="/updates/kernel/drivers/nvme/host/"
MAKE="make -C product/hptnvme/linux HPT_ROOT=${source_tree}/${PACKAGE_NAME}-${PACKAGE_VERSION} V=1"
POST_BUILD="sudo /usr/src/linux-headers-${kernelver}/scripts/sign-file sha256 /var/lib/shim-signed/mok/MOK.priv /var/lib/shim-signed/mok/MOK.der ${dkms_tree}/${PACKAGE_NAME}/${PACKAGE_VERSION}/${architecture}/module/hptnvme.ko"
AUTOINSTALL="yes"
INNER_EOF

    sudo dkms add -m hptnvme -v 1.6.22.0
    sudo dkms build -m hptnvme -v 1.6.22.0
    sudo dkms install -m hptnvme -v 1.6.22.0
    
    echo "-> Module compilation complete."
    echo ""
    
    read -p "Would you like to hot-reload the running system driver into memory right now? (y/N): " LOAD_CHOICE
    if [[ "$LOAD_CHOICE" =~ ^[Yy]$ ]]; then
        sudo umount /dev/sd* 2>/dev/null || true
        if lsmod | grep -q "hptnvme"; then sudo rmmod hptnvme; fi
        sudo modprobe -v hptnvme
        echo "========================================================================"
        echo "SUCCESS: The modernized driver is compiled, registered, and LIVE in memory!"
        echo "========================================================================"
        sudo dmesg | grep -i hptnvme | tail -n 4
    fi
fi
