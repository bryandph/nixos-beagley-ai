# SD boot diagnosis

Keep the original Debian SD available as the serial and boot-chain control.
Power off before swapping cards. Initial NixOS images leave NVMe unmounted.
The public fixture enables serial root autologin and disables SSH; consumer
identity must be composed separately before network login acceptance.

Capture the debug UART at 115200 8N1 before applying power. A PHY link or a
power-transition null byte does not establish that SPL ran. The first useful
boot milestone is the R5 `U-Boot SPL` banner, followed by authentication,
ATF/OP-TEE, A53 SPL, U-Boot, and Linux. If the new card is silent, first verify
that the original card still produces readable output with the same probe.

Build `packages.aarch64-linux.beagley-ai-sd-image` and run
`checks.aarch64-linux.sd-image-layout` before writing a card. Re-identify the
removable medium each time: macOS can report its built-in SD reader as an
internal physical device. Check capacity and reader identity, not only the
external/internal designation. Unmount before writing; flush and eject after.
Compare the three flashed boot-file hashes with the image when diagnosing a
silent boot. Never use an assumed disk number for an unattended write.

The pinned Armbian `config/sources/families/include/k3_common.inc` explicitly
uses `mkfs.fat -a` to fill the partition without alignment rounding. Preserve
that option and check the FAT BPB total-sector count against the MBR partition
size; a generic filesystem reader accepting an image does not prove ROM
compatibility. Do not infer that a zero BPB hidden-sector count prevents boot:
the operator's working Debian FAT32 card uses zero. Its partition is active,
type 0x0c, starts at sector 2048 and has 524288 sectors; that is a useful
alternative layout for a controlled boot experiment, not a universal board
requirement. Hardware acceptance is tracked in `hardware.md`.
