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

## Image identity and retained generations

The SD image profile checks both filesystem labels before mounting the root.
Exactly one `BEAGLEYBOOT` FAT filesystem and one `BEAGLEY_ROOT` ext4 filesystem
must resolve to different partitions of the same physical SD card. Device names
such as `mmcblk0` are not assumed. Duplicate labels, missing filesystems, split
cards, eMMC and NVMe roots are rejected by this SD-only profile; the reusable
core module does not impose this root-device restriction. Both legacy and
systemd initrds run the guard. Repair ambiguous media from the recovery console
before continuing; do not remove the guard to conceal duplicate identities.

`system.build.beagleyAiSdImageCheck` checks MBR signatures, partition types and
bounds, FAT metadata, filesystem identities and extlinux references. It counts
free FAT clusters and budgets the configured retained generations using the
current generation's kernel/initrd/DT size, plus per-generation and fixed
headroom. This verifies capacity for similarly sized generations; arbitrary
future kernel growth is not guaranteed. Continue monitoring `/boot` free space
before retaining additional or substantially larger generations.

The boot structure check verifies HS-FS ROM certificate signatures and fixed
validity dates, SHA-512 component digests, ROM load destinations, FIT stage
addresses and staging bounds. The ROM's physical payload order is SBL, encrypted
TIFS, TIFS board configuration, inner TIFS certificate and DM board configuration.
The inner authentication certificate is not a component to load at address zero.
U-Boot's J722S fixup relocates the TF-A reserved-memory node to its configured
ATF load address; the static Linux DT reservation alone does not describe this
boot-stage relocation. These checks use the public boot artifacts and do not
read operator private keys.
