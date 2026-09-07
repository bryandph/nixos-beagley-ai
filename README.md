# NixOS on BeagleY-AI

Reusable board support for the 4 GB BeagleY-AI, based on the TI J722S/AM67A.
Bring-up is in progress. A successful build is not hardware acceptance.

The public flake exports `nixosModules.beagley-ai-core` and
`nixosModules.beagley-ai-sd-image`. The fixture image provides local serial
root autologin at 115200 8N1, DHCP Ethernet, and no SSH service. Consumers
configure their own accounts and SSH keys. No private fleet data is needed.

```sh
nix run .#fmt
nix build .#packages.x86_64-linux.beagley-ai-arm-trusted-firmware
nix build .#packages.x86_64-linux.beagley-ai-optee
nix build .#packages.x86_64-linux.beagley-ai-boot-bundle
nix build .#packages.aarch64-linux.beagley-ai-sd-image
```

Boot tools can cross-build on x86 Linux. The target image uses AArch64 Linux
builders. Darwin exposes formatting and can drive configured remote builders.

`packages/release.nix` owns source revisions, hashes, boot selections and
firmware member checks. The provider follows the pinned Armbian BeagleBoard
6.12 recipe, including USB/PCIe board supplements. It builds TF-A, OP-TEE and
both U-Boot stages from source. TIFS and system Device Manager are vendor
binaries; their TI-device-only redistribution terms and notices are preserved.
The repository contains recipes, not copied SDK/firmware payloads.

Use spare microSD media for bring-up. The initial image mounts only SD root
and `/boot`; existing NVMe must remain unmounted and unmodified. The boot ROM
loads `tiboot3.bin`, `tispl.bin`, and `u-boot.img` from FAT. Extlinux retains
kernel/initrd/DTB generations. Early boot firmware rollback requires the
known-good card or image; it is separate from NixOS generation rollback.

See [hardware coverage](docs/hardware.md) for scope and acceptance boundaries.
Ethernet is the first milestone; wireless, multimedia, expansion and
accelerators are subsequent stages of the same BSP change.
