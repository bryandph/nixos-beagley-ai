# NixOS on BeagleY-AI

Reusable board support for the 4 GB BeagleY-AI, based on the TI J722S/AM67A.
The server milestone has been exercised on hardware: cold and warm boot,
four CPUs, 3.7 GiB usable RAM, SD root growth, Gigabit Ethernet, and consumer
declarative SSH/firewall configuration. Full hardware enablement remains open;
accelerators, wireless and multimedia are not yet implemented. See the
[hardware coverage matrix](docs/hardware.md) for verification limits and
intermittent peripheral behavior.

The public flake exports `nixosModules.beagley-ai-core` and
`nixosModules.beagley-ai-sd-image`. The fixture image provides local serial
root autologin at 115200 8N1, DHCP Ethernet, and no SSH service. Consumers
configure their own accounts and SSH keys. No private fleet data is needed.
Serial autologin belongs to the fixture configuration, not the exported board
modules. Fleet identity, secrets and deployment policy belong in the consumer.

```sh
nix run .#fmt
nix build .#packages.x86_64-linux.beagley-ai-arm-trusted-firmware
nix build .#packages.x86_64-linux.beagley-ai-optee
nix build .#packages.x86_64-linux.beagley-ai-boot-bundle
nix build .#packages.aarch64-linux.beagley-ai-sd-image
nix build .#checks.aarch64-linux.sd-image-layout
```

Boot tools can cross-build on x86 Linux. The target image uses AArch64 Linux
builders. Darwin exposes formatting and can drive configured remote builders.

For a consumer configuration, import both board modules and build
`nixosConfigurations.<host>.config.system.build.beagleyAiSdImage`. This is
the board-specific image output with the ROM-compatible FAT layout; the generic
`system.build.sdImage` does not include that layout correction. The public
`packages.aarch64-linux.beagley-ai-sd-image` already selects the correct output.
Consumers must also allow the required TI firmware packages under their Nixpkgs
unfree policy; see [the fixture](modules/fixture.nix) for the package allowlist.

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

See [SD boot and recovery](docs/boot-recovery.md) before flashing or diagnosing
a silent boot. The image layout check validates FAT geometry, boot references
and load ranges; it does not replace a physical boot test.

Ethernet is the first milestone; wireless, multimedia, expansion and
accelerators are subsequent stages of the same BSP change.
