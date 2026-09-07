# Hardware coverage

Initial NixOS cold-boot evidence exists for the core, Ethernet and PCIe paths;
complete acceptance of those rows remains open. `pending` means implementation
is still open; it is not a final disposition. Completed rows distinguish
`verified`, `implemented-unverified` (including missing fixtures), and an
evidence-backed `blocked` disposition. Source presence or device enumeration
alone does not establish functional support.

| Interface | Owning implementation | Acceptance | Current disposition |
| --- | --- | --- | --- |
| Boot/UART/CPU/RAM/SD | core and SD-image modules | ROM-to-login capture, four CPUs, explained RAM, cold/warm boot, generation rollback | cold boot to serial root verified; four CPUs, 3.7 GiB usable RAM and SD growth observed; warm boot/rollback pending |
| Ethernet | core, AM65 CPSW | DHCP, SSH under consumer identity, sustained connectivity across boots | DHCP, gateway traffic and temporary operator-key SSH verified; declarative identity and sustained tests pending |
| PCIe/NVMe | core, board DT supplement | link/controller/namespace and read-only health; no filesystem mount or writes | Gen3 x1 controller/namespace enumeration verified after full power removal; health and power-transition reliability pending; filesystem unmounted |
| USB-A | core, Cadence and hub DT | USB2/USB3 negotiation, attached devices, repeated boots | both four-port hubs enumerate after transient reset/protocol errors; attached-device and repeat-boot tests pending |
| Thermal/fan/CPU idle/frequency | core kernel/DT | bounded load only after cooling check; thermal and clock evidence | pending hardware test |
| RTC/watchdog/LEDs/buttons/power | core kernel/DT | controls, retention and recoverable watchdog/reboot tests | pending hardware test |
| Wi-Fi/BLE | wireless module | matched CC33xx SDK, Wi-Fi data/reconnect and BLE GATT peer | pending implementation |
| USB-C device | gadget module | serial/network gadget enumeration and traffic | pending implementation |
| HDMI/audio/McASP | multimedia and expansion modules | actual output/modes and playback on identified sink/HAT | pending implementation |
| PowerVR GPU | multimedia module | matched BVNC/KMD/UM firmware, EGL and supported Vulkan, no CPU renderer | pending implementation |
| Wave5/E5010 | multimedia module | supported encode/decode/JPEG operations with valid output | pending implementation |
| CSI0/CSI1 and VPAC | camera module | IMX219 raw and ISP capture, mode-specific DCC/2A, per-connector results | pending implementation |
| DSI/OLDI | panel profiles | identified panel/bridge/mode, CSI1 resource conflict checks | pending implementation |
| GPIO/I2C/SPI/UART/PWM | expansion module | free-pin fixtures and documented line identities; protect PMIC/EEPROM/console | pending implementation |
| Application R5 | remoteproc module | stable hardware identity, resource tables and IPC; protect system DM | pending implementation |
| Both C7x/MMA and vision R5 | Edge AI module | source-rebuilt 4 GB memory ABI, RPMsg and TIDL offload; Linux retains CPSW | pending implementation |
| OP-TEE/RNG/debug | core and tools | non-destructive interface tests; no fuse provisioning | pending hardware test |

The complete provider must pass concurrent compatible workloads within its
thermal and memory budget. Optional imports describe consumer choice, not
deferral of feasible hardware work. No application lifecycle operation may
stop or replace the system Device Manager core.

The kernel, DT, firmware resource tables and Linux accelerator libraries must
share one memory ABI. BeagleY has split physical RAM banks: an address above
4 GiB is not inherently invalid. Stock 8 GB J722S EVM firmware is not suitable.

## Source authority

- Boot/provider tuple: `packages/release.nix`, pinned
  [Armbian family recipe](https://github.com/armbian/build/blob/d3298cac2223892b668ab27e95237448eeb75f26/config/sources/families/k3-beagle.conf).
- Board design and connectors: [BeagleBoard documentation](https://docs.beagleboard.org/boards/beagley/ai/03-design.html).
- 4 GB vision firmware and Linux ABI patches: [BeagleY Edge AI builder](https://github.com/TexasInstruments-Sandbox/ti-edgeai-armbian-build/tree/be3a57d2760691f6b4f5cc7cae6e00ccddef7016).
- R5/C7x AI startup must apply the reference no-EthFW ownership changes, keeping
  Ethernet under Linux throughout startup and workload tests.
