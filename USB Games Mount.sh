#!/bin/bash

# --- Verification root ---
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

# --- Configuration ---
USB_DEV="/dev/sda1"
USB_MNT="/mnt/usbdrive"
ES_SYSTEMS="/etc/emulationstation/es_systems.cfg"
BIND_DIR_NAME="USB"
PORTS_DIR_NAME="ports"
MOUNT_MARKER="/tmp/usb_games_mount_mounted_usb"
MOUNT_TARGETS="/tmp/usb_games_mount_targets"
USB_PORT_COUNT=0

# --- Console ---
setup_console_font() {
    if compgen -G "/boot/rk3566*" > /dev/null; then
        if test ! -z "$(cat /home/ark/.config/.DEVICE | grep RGB20PRO | tr -d '\0')"; then
            setfont /usr/share/consolefonts/Lat7-TerminusBold32x16.psf.gz
        else
            setfont /usr/share/consolefonts/Lat7-TerminusBold28x14.psf.gz
        fi
    fi
}

# --- Active roms path ---
get_active_rom_path() {
    if [ -f "$ES_SYSTEMS" ] && grep -q "<path>/roms2/" "$ES_SYSTEMS"; then
        echo "/roms2"
    else
        echo "/roms"
    fi
}

# --- Filesystem ---
get_filesystem() {
    local SOURCE_DEV=$1
    local FSTYPE

    FSTYPE=$(blkid -o value -s TYPE "$SOURCE_DEV" 2>/dev/null)
    if [ -z "$FSTYPE" ]; then
        FSTYPE=$(lsblk -no FSTYPE "$SOURCE_DEV" 2>/dev/null)
    fi

    if [ "$FSTYPE" = "ntfs" ] && command -v ntfs-3g >/dev/null 2>&1; then
        FSTYPE="ntfs-3g"
    fi

    echo "$FSTYPE"
}

get_mount_options() {
    local FSTYPE=$1

    if [[ "$FSTYPE" =~ ^(vfat|exfat|ntfs|ntfs-3g)$ ]]; then
        echo "rw,uid=1000,gid=1000,umask=000,noatime"
    else
        echo "rw,noatime"
    fi
}

# --- USB mount ---
mount_usb_drive() {
    local FSTYPE
    local OPTS

    if mountpoint -q "$USB_MNT"; then
        return 0
    fi

    if [ ! -b "$USB_DEV" ]; then
        echo "ERROR: No USB drive found at $USB_DEV."
        return 1
    fi

    FSTYPE=$(get_filesystem "$USB_DEV")
    if [ -z "$FSTYPE" ]; then
        echo "ERROR: Could not detect the USB filesystem."
        return 1
    fi

    OPTS=$(get_mount_options "$FSTYPE")

    mkdir -p "$USB_MNT"
    if mount -t "$FSTYPE" -o "$OPTS" "$USB_DEV" "$USB_MNT"; then
        touch "$MOUNT_MARKER"
        echo ">>> USB drive mounted to $USB_MNT."
        return 0
    fi

    echo "ERROR: Could not mount $USB_DEV to $USB_MNT."
    return 1
}

# --- USB game binds ---
record_mount_target() {
    echo "$1" >> "$MOUNT_TARGETS"
}

has_usb_game_mounts() {
    if [ -f "$MOUNT_TARGETS" ]; then
        while read -r TARGET; do
            if [ -n "$TARGET" ] && mountpoint -q "$TARGET"; then
                return 0
            fi
        done < "$MOUNT_TARGETS"
    fi

    findmnt -rn -o TARGET | grep -qE "^/(roms|roms2)/[^/]+/$BIND_DIR_NAME$|^/(roms|roms2)/$PORTS_DIR_NAME/[^/]+$"
}

unmount_usb_games() {
    local TARGET
    local TARGETS
    local FOUND=0

    if [ -f "$MOUNT_TARGETS" ]; then
        TARGETS=$(sort -ru "$MOUNT_TARGETS" | sort -r)
    else
        TARGETS=$(findmnt -rn -o TARGET | grep -E "^/(roms|roms2)/[^/]+/$BIND_DIR_NAME$|^/(roms|roms2)/$PORTS_DIR_NAME/[^/]+$" | sort -r)
    fi

    while read -r TARGET; do
        if [ -z "$TARGET" ]; then
            continue
        fi

        FOUND=1
        umount -l "$TARGET" 2>/dev/null
        if [ -d "$TARGET" ]; then
            rmdir "$TARGET" 2>/dev/null
        else
            rm -f "$TARGET" 2>/dev/null
        fi
        echo ">>> Removed $TARGET."
    done <<< "$TARGETS"

    rm -f "$MOUNT_TARGETS"

    if [ -f "$MOUNT_MARKER" ] && mountpoint -q "$USB_MNT"; then
        umount -l "$USB_MNT" 2>/dev/null
        rm -f "$MOUNT_MARKER"
        echo ">>> USB drive unmounted from $USB_MNT."
    fi

    systemctl restart emulationstation
    return $FOUND
}

mount_usb_ports() {
    local ACTIVE_ROM_PATH=$1
    local USB_PORTS_DIR="$USB_MNT/$PORTS_DIR_NAME"
    local ACTIVE_PORTS_DIR="$ACTIVE_ROM_PATH/$PORTS_DIR_NAME"
    local SRC_PATH
    local PORT_NAME
    local TARGET_PATH

    USB_PORT_COUNT=0

    if [ ! -d "$USB_PORTS_DIR" ] || [ ! -d "$ACTIVE_PORTS_DIR" ]; then
        return 0
    fi

    for SRC_PATH in "$USB_PORTS_DIR"/*; do
        if [ ! -e "$SRC_PATH" ]; then
            continue
        fi

        PORT_NAME=$(basename "$SRC_PATH")
        TARGET_PATH="$ACTIVE_PORTS_DIR/$PORT_NAME"

        if [ -e "$TARGET_PATH" ]; then
            echo ">>> Skipped $PORT_NAME, already exists in $ACTIVE_PORTS_DIR."
            continue
        fi

        if [ -d "$SRC_PATH" ]; then
            mkdir -p "$TARGET_PATH"
        else
            touch "$TARGET_PATH"
            chmod --reference="$SRC_PATH" "$TARGET_PATH" 2>/dev/null
        fi

        if mount --bind "$SRC_PATH" "$TARGET_PATH"; then
            USB_PORT_COUNT=$((USB_PORT_COUNT + 1))
            record_mount_target "$TARGET_PATH"
            echo ">>> Added USB port item $PORT_NAME."
        else
            if [ -d "$TARGET_PATH" ]; then
                rmdir "$TARGET_PATH" 2>/dev/null
            else
                rm -f "$TARGET_PATH" 2>/dev/null
            fi
        fi
    done
}

mount_usb_games() {
    local ACTIVE_ROM_PATH=$1
    local SRC_DIR
    local SYSTEM_NAME
    local TARGET_PARENT
    local TARGET_DIR
    local COUNT=0
    local PORT_COUNT=0
    local USB_PORT_COUNT=0

    if ! mount_usb_drive; then
        return 1
    fi

    for SRC_DIR in "$USB_MNT"/*; do
        if [ ! -d "$SRC_DIR" ]; then
            continue
        fi

        SYSTEM_NAME=$(basename "$SRC_DIR")
        if [ "$SYSTEM_NAME" = "$PORTS_DIR_NAME" ]; then
            mount_usb_ports "$ACTIVE_ROM_PATH"
            PORT_COUNT=$USB_PORT_COUNT
            COUNT=$((COUNT + PORT_COUNT))
            continue
        fi

        TARGET_PARENT="$ACTIVE_ROM_PATH/$SYSTEM_NAME"
        TARGET_DIR="$TARGET_PARENT/$BIND_DIR_NAME"

        if [ ! -d "$TARGET_PARENT" ]; then
            continue
        fi

        if mountpoint -q "$TARGET_DIR"; then
            continue
        fi

        mkdir -p "$TARGET_DIR"
        if mount --bind "$SRC_DIR" "$TARGET_DIR"; then
            COUNT=$((COUNT + 1))
            record_mount_target "$TARGET_DIR"
            echo ">>> Added $SYSTEM_NAME USB games."
        else
            rmdir "$TARGET_DIR" 2>/dev/null
        fi
    done

    if [ "$COUNT" -eq 0 ]; then
        echo "ERROR: No matching game folders were found on the USB drive."
        return 1
    fi

    systemctl restart emulationstation
    echo ">>> $COUNT USB game and port items are now available from $ACTIVE_ROM_PATH."
    return 0
}

# --- Depart ---
setup_console_font
clear
echo "=================================================="
echo "          USB GAMES MOUNT                         "
echo "=================================================="

if has_usb_game_mounts; then
    echo "Unmounting USB games..."
    unmount_usb_games
    echo "=================================================="
    sleep 3
    exit 0
fi

ACTIVE_ROM_PATH=$(get_active_rom_path)
echo "Active roms path: $ACTIVE_ROM_PATH"
echo "Mounting USB games..."

if mount_usb_games "$ACTIVE_ROM_PATH"; then
    echo "=================================================="
    sleep 3
    exit 0
fi

echo "=================================================="
sleep 5
exit 1
