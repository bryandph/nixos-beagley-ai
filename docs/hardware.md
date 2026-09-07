# Hardware coverage

The NixOS server milestone has passed cold and warm boot with a consumer's
declarative SSH identity and firewall. Complete acceptance of every interface
below remains open. `pending` means implementation
is still open; it is not a final disposition. Completed rows distinguish
`verified`, `implemented-unverified` (including missing fixtures), and an
evidence-backed `blocked` disposition. Source presence or device enumeration
alone does not establish functional support.

| Interface | Owning implementation | Acceptance | Current disposition |
| --- | --- | --- | --- |
| Boot/UART/CPU/RAM/SD | core and SD-image modules | ROM-to-login capture, four CPUs, explained RAM, cold/warm boot, generation rollback | cold and warm boot verified; four CPUs, 3.7 GiB usable RAM and SD growth observed; booted the previous generation and restored the fleet generation successfully |
| Ethernet | core, AM65 CPSW | DHCP, SSH under consumer identity, sustained connectivity across boots | Gigabit link, DHCP, gateway traffic and declarative consumer SSH/firewall verified after warm reboot; sustained load tests pending |
| PCIe/NVMe | core, board DT supplement | link/controller/namespace and read-only health; no filesystem mount or writes | Gen3 x1 controller/namespace enumeration verified across rollback and current warm boots; read-only SMART reports zero critical warnings, media errors and error-log entries; earlier missing-device boots and cold power-transition reliability remain unresolved; filesystem unmounted |
| USB-A | core, Cadence and hub DT | USB2/USB3 negotiation, attached devices, repeated boots | built-in hub reset ownership verified before enumeration; first changed-kernel boot has both four-port hubs at 480/5000 Mbit/s without prior reset/protocol errors; attached-device and repeated warm/cold-boot tests pending |
| Thermal/fan/CPU idle/frequency | core kernel/DT | bounded load only after cooling check; thermal and clock evidence | heatsink fitted, no fan; shared four-core cpufreq-dt policy and 200–1200 MHz table verified; passive cooling limits the policy to 200 MHz above 60 °C; controlled frequency transitions, cooldown, CPU idle and load acceptance pending |
| RTC/watchdog/LEDs/buttons/power | core kernel/DT | controls, retention and recoverable watchdog/reboot tests | DS1340 initialization/readback and stable rtc0 ordering verified across warm reboot; internal RTC is rtc1 and remains unvalidated; backup battery absent, operator waived retention test; orderly shutdown/reboot verified; watchdog and remaining controls pending |
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

Current server verification uses USB-C power. The attached third-party PoE/NVMe
HAT has an unresolved PoE power-up fault; PoE operation is not accepted. Its
NVMe path is covered separately above. Consumer fleet management and secrets
enrollment do not establish acceptance of untested board hardware.

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
