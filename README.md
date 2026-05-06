# USB & SD2 Games Monitor

A bash-based set of helper scripts for retro-gaming handhelds and consoles. The original project provides an automatic USB/SD2 ROM monitor, while this fork also includes a manual USB games mount option for users who prefer to keep the system's normal `/roms` and `/roms2` setup untouched.

Special thanks to **@SjslTech** for the original work and contribution to this project.

## Choose Your Workflow

This fork keeps the original behavior available and adds an optional alternative. Use whichever script matches the way you want your device to handle external storage.

### `USB Games.sh`

This is the original automatic monitor script.

- Installs a systemd service named `usb-games-monitor`.
- Watches for USB at `/dev/sda1` or SD2 at `/dev/mmcblk1p1`.
- Mounts the detected external device as the active `/roms` directory.
- Restores the internal ROM partition when the external device is removed.
- Copies and bind-mounts `themes`, `tools`, and `Tools` support folders as needed.

This is useful if you want the external USB or SD2 device to become the main ROM source automatically.

### `USB Games Mount.sh`

This is the optional manual script added in this fork.

- Does not install a background service.
- Does not automatically watch for devices.
- Does not replace `/roms` or `/roms2`.
- Mounts USB at `/mnt/usbdrive`.
- Detects whether EmulationStation is currently using `/roms` or `/roms2`.
- Adds matching USB game folders under the active ROM path, for example `/roms2/gba/USB`.
- Keeps the games already on the active SD card available, so you can play games from both the USB drive and the SD card currently in use.
- Handles USB ports specially by exposing port scripts and folders directly inside the active `ports` folder when there is no name conflict.
- Running the script again unmounts the USB game and port bindings.

This is useful if you already use the built-in ArkOS/dArkOS SD2 mode, or the main SD card for ROMs, and only want USB games or ports added when you choose to mount them. The USB content works together with the games already present on the active storage instead of replacing that storage.

## Folder Creation Scripts

The folder creation scripts help prepare a USB drive or SD2 card with the expected ArkOS/dArkOS folder structure.

- `Folder Creation Script.bat` is for Windows.
- `Folder Creation Script.sh` is for Linux.

Run the folder creation script from the root of the USB or SD2 drive. It creates the system folders in the current directory and then removes itself.

## Supported Formats

The scripts detect and use suitable mount options for common filesystems:

- FAT32 (`vfat`)
- exFAT
- NTFS
- ext4

## Installation

1. Copy all ArkOS or dArkOS system folders to your USB or SD2 drive, or run one of the folder creation scripts from the drive root.
2. Place your games in the matching system folders.
3. Choose which script you want to use:
   - Copy `USB Games.sh` to `roms/tools` if you want the original automatic monitor behavior.
   - Copy `USB Games Mount.sh` to `roms/tools` or `roms2/tools` if you want the manual optional USB mount behavior.
4. Run the chosen script from the Tools menu.

Enjoy.

### A coffee to offer?

[https://ko-fi.com/jason3x](https://ko-fi.com/jason3x)
