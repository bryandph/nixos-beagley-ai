# NixOS on BeagleY-AI

Reusable board support for the 4 GB BeagleY-AI (TI J722S/AM67A). A consumer fleet
host runs this provider with declarative SSH, firewall and secrets enrollment.
Cold/warm SD boot, generation rollback and restoration, Gigabit Ethernet,
CPU frequency control and external RTC ordering have been exercised. The kernel
exposes both USB host hubs and Gen3 x1 NVMe without mounting the NVMe filesystem.

Wireless firmware now initializes Wi-Fi and Bluetooth controllers. The matched
PowerVR stack reports hardware Vulkan, EGL and OpenCL and passes a bounded compute
test. E5010 encoded a valid JPEG frame; Wave5 H.264 encode/decode and H.265 decode
matched software-decoded pixels across ten frames. Source-compiled RegNet offloaded
all 103 nodes on each C7x core and passed CPU-output comparison on synthetic input.
Wireless peer traffic, cameras, panels, expansion fixtures and broader workload
coverage retain their own acceptance requirements. See the [hardware matrix](docs/hardware.md)
for exact results and remaining gaps. The third-party HAT's PoE fault remains
unresolved; current runtime verification uses USB-C power.

## Consumer modules

All names below are exported through `nixosModules`. Compose optional hardware
profiles with the core; they do not carry private fleet identity or credentials.

| Module name after `beagley-ai-` | Purpose |
| --- | --- |
| `full` | Core, multimedia, GPU, wireless, vision, accelerator runtime and camera tooling; connector profiles remain opt-in |
| `core` | Coordinated kernel, DT, serial console, thermal policy and firmware handling |
| `sd-image` | SD root/boot, ROM-compatible FAT image, extlinux generations and identity guard |
| `wireless` | Matched CC3301 Wi-Fi/BLE firmware and Bluetooth initialization |
| `multimedia` | Wave5 codec firmware and video tools |
| `gpu` | Matched PowerVR kernel module, firmware, Mesa and Vulkan/OpenCL libraries |
| `csi0-imx219`, `csi1-imx219` | Identified IMX219 connector routes |
| `camera` | ISP tools, IMX219 tuning and camera-to-TIDL runner; compose vision/runtime explicitly |
| `dsi-rpi-7inch`, `oldi-lcd185` | Identified panel/bridge routes |
| `header-gpio14-15`, `header-uart1` | Header GPIO or UART routes |
| `header-i2c-400khz`, `header-spi0` | Header I2C timing or native SPI controller |
| `header-pwm14`, `header-pwm12`, `header-mcasp0` | PWM or I2S controller/pin routes |
| `usb-gadget` | Explicit USB-C ACM/ECM peripheral role; requires suitable independent power |
| `remoteproc-ipc` | Application R5/C7x IPC firmware, fixed core ownership and guarded lifecycle |
| `vision` | Source-rebuilt 4 GB vision firmware and matching reserved-memory profile |
| `accelerator-runtime` | Matched Linux vision/TIDL/OSRT libraries and tools |
| `regnet-model` | RegNet ONNX recompiled with matched x86 TIDL tools and deterministic calibration |

For example, a consumer supplies its own users, networking and deployment policy:

```nix
imports = [
  inputs.nixos-beagley-ai.nixosModules.beagley-ai-full
  inputs.nixos-beagley-ai.nixosModules.beagley-ai-sd-image
];
```

Add only connector profiles for attached hardware. The aggregate includes core already;
do not import its constituent features a second time. It selects vision firmware,
so use a separate IPC composition for IPC echo/lifecycle diagnostics. A smaller
server composition can import core and individual features instead of full.

Header and media profiles reject known pin/controller conflicts. SPI requires
an actual peripheral description; McASP requires a codec and sound-card binding.
The IPC and vision profiles are mutually exclusive and require a reboot when
changing memory ABI. Importing runtime libraries alone does not select a remote-processor memory map
or establish accelerator offload. Follow the [accelerator firmware](docs/accelerator-firmware.md)
and [runtime](docs/accelerator-runtime.md) contracts. See [model compilation](docs/model-compilation.md)
for the source-only RegNet build, isolated rebuild check and license limits.

The standalone fixture enables local serial root autologin at 115200 8N1,
DHCP Ethernet and no SSH service. Autologin belongs to that fixture, not the
exported board modules. Consumers must allow the selected TI firmware packages
under their Nixpkgs unfree policy; see [the full fixture allowlist](modules/full-fixture.nix) and each
optional package's license metadata. The provider preserves uncompressed
firmware because the coordinated kernel lacks firmware decompression support.

## Build and verify

```sh
nix run .#fmt
nix build .#packages.x86_64-linux.beagley-ai-boot-bundle
nix build .#packages.aarch64-linux.beagley-ai-sd-image
nix build .#checks.x86_64-linux.boot-structure
nix build .#checks.aarch64-linux.device-tree-contract
nix build .#checks.aarch64-linux.sd-identity-guard
nix build .#checks.aarch64-linux.sd-image-layout
nix build .#checks.aarch64-linux.expansion-profiles
nix build .#checks.aarch64-linux.media-profiles
nix build .#checks.aarch64-linux.accelerator-ipc-dt
nix build .#checks.aarch64-linux.accelerator-vision-dt
nix build .#checks.x86_64-linux.accelerator-lifecycle
nix build .#checks.aarch64-linux.full-feature-composition
nix build .#checks.aarch64-linux.full-feature-system
# Optional full-stack image for identified spare SD media:
nix build .#packages.aarch64-linux.beagley-ai-full-sd-image
```

Boot tools can cross-build on x86 Linux. Target images use configured AArch64
Linux builders; Darwin can drive those builders. The public image package and
consumer `config.system.build.beagleyAiSdImage` select the board-specific FAT
correction. Generic `system.build.sdImage` does not. Consumers can check their
actual composition through `system.build.beagleyAiSdImageCheck`,
`beagleyAiDeviceTreeCheck` and, with wireless imported, `beagleyAiWirelessCheck`.

Use identified spare SD media. The image mounts only SD root and `/boot`;
existing NVMe remains unmounted and unmodified. ROM loads `tiboot3.bin`,
`tispl.bin` and `u-boot.img` from FAT. Extlinux generation rollback is separate
from early firmware recovery using a known-good card. Read [boot and recovery](docs/boot-recovery.md)
before flashing: checks cover layout, identities, generation capacity and load
ranges, while physical boot remains a separate acceptance step.

Source revisions, hashes, licenses and ABI mappings live in `packages/release.nix`
and feature-specific release metadata. TF-A, OP-TEE and U-Boot build from source;
TIFS and system Device Manager remain vendor binaries with preserved notices.
The repository contains recipes rather than copied SDK payloads.

Further references: [cooling and power controls](docs/cpu-cooling.md),
[USB host](docs/usb-host.md), [RTC](docs/rtc.md), [wireless](docs/wireless.md),
[multimedia](docs/multimedia.md), [header expansion](docs/expansion.md),
[USB gadget](docs/usb-gadget.md), and [core diagnostics](docs/core-diagnostics.md).
