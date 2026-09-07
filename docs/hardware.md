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
| Boot/UART/CPU/RAM/SD | core and SD-image modules | ROM-to-login capture, four CPUs, explained RAM, cold/warm boot, generation rollback | cold and warm boot verified; four CPUs and SD growth observed; core profile has 3.7 GiB usable RAM, while the vision profile reserves accelerator/CMA memory and exposes 2583 MiB to Linux; booted the previous generation and restored the fleet generation successfully |
| Ethernet | core, AM65 CPSW | DHCP, SSH under consumer identity, sustained connectivity across boots | Gigabit link, DHCP and declarative consumer SSH/firewall verified across boots; 60/60 gateway replies during concurrent inference on both C7x, GPU compute and 20-second/200-frame H.264 hardware encode, with no failed units |
| PCIe/NVMe | core, board DT supplement | link/controller/namespace and read-only health; no filesystem mount or writes | Gen3 x1 controller/namespace enumeration verified across rollback and current warm boots; read-only SMART reports zero critical warnings, media errors and error-log entries; cold power transitions remain implemented-unverified; the cause of earlier missing-device boots remains unresolved; filesystem unmounted |
| USB-A | core, Cadence and hub DT | USB2/USB3 negotiation, attached devices, repeated boots | built-in hub reset ownership verified before enumeration; first changed-kernel boot has both four-port hubs at 480/5000 Mbit/s without prior reset/protocol errors; attached-device and repeated warm/cold-boot coverage implemented-unverified |
| Thermal/fan/CPU idle/frequency | core kernel/DT | bounded load only after cooling check; thermal and clock evidence | heatsink fitted, no fan; shared four-core cpufreq-dt policy and 200–1200 MHz table verified; initial 60 °C example over-throttled at idle; revised 85 °C/5 °C policy booted with 1200 MHz maximum at 63.7 °C. Baseline WFI available; deep idle blocked by firmware advertising no CPU_SUSPEND. 45-second four-process SHA-256 load held 1.2 GHz with a 69.717 °C peak. Trip/cooldown and physical fan operation implemented-unverified; no fan fixture |
| RTC/watchdog/LEDs/buttons/power | core kernel/DT | controls, retention and recoverable watchdog/reboot tests | DS1340 initialization/readback and stable rtc0 ordering verified across warm reboot; internal RTC is rtc1 and remains unvalidated; backup battery absent, operator waived retention test; orderly shutdown/reboot verified; watchdog identity available without arming; ACT heartbeat and PWR none triggers, tps65219-pwrbutton event0 and PWM-fan interfaces present. Recoverable watchdog expiry and physical control observation implemented-unverified |
| Wi-Fi/BLE | wireless module | matched CC33xx SDK, Wi-Fi data/reconnect and BLE GATT peer | implemented: matched firmware initializes wlan0 and Bluetooth HCI; initialization service passes. Association, sustained data/reconnect and GATT peer operation implemented-unverified; peer fixtures absent |
| USB-C device | gadget module | serial/network gadget enumeration and traffic | implemented-unverified: ACM/ECM service and peripheral DT compile; UDC present. Independent-power/data fixture needed; not activated on USB-C-powered host |
| HDMI/audio/McASP | multimedia and expansion modules | actual output/modes and playback on identified sink/HAT | implemented-unverified: it66122 HDMI ALSA card0 and McASP header route; HDMI reports disconnected and physical HDMI/audio sink absent. McASP additionally needs identified codec/card binding |
| PowerVR GPU | GPU module | matched BVNC/KMD/UM firmware, EGL and supported Vulkan, no CPU renderer | hardware API initialization verified: PowerVR BXS4-64, driver 25.2@6850647, Vulkan 1.4.314, EGL 1.5 GBM/surfaceless and OpenCL PowerVR. Bounded RGX compute test passed 16 kicks without fault injection; display rendering fixtures remain absent |
| Wave5/E5010 | multimedia module | supported encode/decode/JPEG operations with valid output | Wave5 video0/video1 and JPEG video2 enumerate; E5010 encoded one 640x480 JPEG verified by ffprobe. Wave5 H.264 encoded and decoded ten 640x480 frames; all decoded pixel hashes matched software with passthrough frame timing. Wave5 H.265 decoded ten software-encoded 640x480 frames; all ten pixel hashes matched software with passthrough frame timing |
| CSI0/CSI1 and VPAC | camera profiles and accelerator runtime | IMX219 raw and ISP capture, mode-specific DCC/2A, per-connector results | IMX219 connector profiles implemented with composed DT checks; sensor fixtures absent. matched VPAC/ISP runtime, mode-specific RAW10 DCC/2A and camera-to-TIDL runner implemented; plugin discovery passes. Physical capture/inference unverified |
| DSI/OLDI | panel profiles | identified panel/bridge/mode, CSI1 resource conflict checks | implemented-unverified: Raspberry Pi 7-inch DSI and LCD185 OLDI profiles compile; compatible combinations and CSI1/DSI plus OLDI/PWM conflicts checked. Panels absent |
| GPIO/I2C/SPI/UART/PWM | expansion module | free-pin fixtures and documented line identities; protect PMIC/EEPROM/console | implemented-unverified: seven source-backed header profiles and composition conflict checks pass. Physical loopback/peripheral fixtures absent; no PMIC/EEPROM bus scan performed |
| Application R5 | IPC profile and guarded lifecycle | stable hardware identity, resource tables and IPC; protect system DM | both application R5s and both C7x cores each passed 100 exact echoes, guarded stop/start and another 100 echoes. Concurrent Ethernet 40/40 replies, DM remained attached. Stable identity, ownership and lifecycle safety checks pass |
| Both C7x/MMA and vision R5 | vision profile and accelerator runtime | source-rebuilt 4 GB memory ABI, RPMsg and TIDL offload; Linux retains CPSW | source-rebuilt firmware and Linux maps match; composed DT checks verify disjoint reservations, RAM budget and DM preservation. All three cores run; MPU heap-stat queries reached each peer with clean deinitialization. Vision lacks shutdown ACK, so live stop is rejected before sysfs; board restart required. Concurrent inference on both C7x, GPU compute, 20-second/200-frame H.264 encode and 60/60 gateway replies passed with no failed units; final highest sensor reading 73.141 C (not a measured peak), with 2164 MiB available Linux RAM. Source-compiled RegNet passed three runs on each C7x, all 103 nodes offloaded with positive TIDL profiling events; both cores produced identical outputs, cosine 0.9978846 and relative L2 0.068401 against CPU. Synthetic integration accepted; classifier accuracy unmeasured |
| OP-TEE/RNG/debug | core and tools | non-destructive interface tests; no fuse provisioning | OP-TEE 4.6 version ioctl and root-only TEE devices verified; optee-rng selected and bounded RNG read to /dev/null passed. No TA session, secure storage, fuse or key operation performed |

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
