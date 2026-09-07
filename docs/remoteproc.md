# Application remote processors

Compose `nixosModules.beagley-ai-remoteproc-ipc` for the narrow TI IPC echo firmware, or
`nixosModules.beagley-ai-vision` for source-built Vision Apps main R5/C7x firmware.
Compose core explicitly; the vision runtime is a separate feature. Importing
both firmware profiles fails evaluation because they claim the same cores.
Changing profiles requires a reboot into the matching DT, then IPC/runtime
acceptance. The service does not restart automatically during a configuration
switch. When leaving IPC, stop `beagley-ai-remoteproc.service` while its old
profile and DT are still active, install the new boot configuration, then
restart the board. Vision firmware replacement requires a board restart;
it does not support the IPC profile's live stop/restart sequence.

| Helper name | Stable hardware identity | IPC firmware | Vision firmware |
| --- | --- | --- | --- |
| `mcu-r5` | `79000000.r5f` | MCU SDK `mcu2_0` | Unmanaged |
| `main-r5` | `78400000.r5f` | MCU SDK `mcu3_0` | Vision Apps `mcu2_0` |
| `c7x0` | `7e000000.dsp` | `c7x_1` | `c7x_1` |
| `c7x1` | `7e200000.dsp` | `c7x_2` | `c7x_2` |

Device Manager at `78000000.r5f` is excluded from both packages and the
lifecycle helper. Its DT reservations and driver binding are preserved.
Never substitute `remoteprocN` enumeration numbers for these identities.

`beagley-ai-remoteproc status [core]` and `start [core]` operate only the
selected profile; `stop [core]` is supported only by IPC firmware.
Before any selected core changes state, the helper
checks exact live DT paths, core reservations, and all selected states and
running firmware owners. Vision additionally requires every declared shared
heap and CMA region to match the live DT and remain enabled. It refuses
attached, detached, crashed or foreign-owned cores. Repeating the desired
running/offline state is a no-op. Linux remoteproc may also autostart firmware
during driver registration; the matching DT and firmware are therefore built
and deployed together.

The pinned Vision Apps shutdown callback is gated to AM62A/C7504 in
`app_utils/utils/ipc/src/app_ipc_rtos.c`, excluding J722S R5/C7524. A board
test confirmed MAIN R5 stop times out with `EBUSY`. Linux had already removed
its RPMsg channels despite the core still reporting running; a board restart
is required to restore them. The vision helper now refuses stop before any
sysfs access, and its service has no `ExecStop`. Do not issue raw remoteproc
stop writes for this firmware.

The IPC profile provides `beagley-ai-ipc-test <core>` for 100 echo messages
with a 20-second timeout. A local patch checks every returned length and
payload and preserves errors through endpoint cleanup; the upstream example
otherwise leaves data integrity unchecked and overwrites errors during close.
It uses the pinned TI library's symbolic processor
mapping, checked at compile time, rather than sysfs enumeration. Test every
core separately while watching Ethernet traffic and the kernel journal.
Endpoint creation alone does not prove payload exchange. After each lifecycle
test confirm Device Manager remains attached and Ethernet remains usable.

## Memory contract

`accelerator-profiles.nix` owns application identity and region associations;
`accelerator-memory.nix` owns the vision DT reservations. Source-built ELF
segments are checked against each core's generated firmware reservation or
R5 TCM. Runtime and firmware generated maps must match byte-for-byte.

The composed host's `system.build.beagleyAiAcceleratorDeviceTreeCheck` checks
the final DT, including both RAM banks, every enabled reservation, overlap,
core phandles, preserved Device Manager/MCU reservations, generated map labels,
and at least 1 GiB remaining for Linux after accounting for CMA. This check is
a host build dependency. The vision map retains upstream's fixed 896 MiB CMA
at `0x8c0000000`, separate from the C7x heaps and 512 MiB shared DMA heap.
Existing C7x reserved node names retain their base-DT unit addresses while
their `reg` properties move to the vision map; checks use actual properties.

Package builds, ELF contracts, composed IPC/vision DT checks and synthetic
lifecycle safety tests pass. On-board IPC acceptance passed on all four
application cores: 100 exact echo replies per core, followed by guarded
all-stop/all-start, an idempotent start, then another 100 replies per core.
Concurrent Ethernet monitoring received 40 of 40 gateway replies without
loss, and Device Manager remained attached throughout. All three source-built
vision cores subsequently booted, and bounded MPU heap-stat queries reached
main R5 and both C7x cores with clean initialization/deinitialization. After
deploying the stop restriction, an explicit stop was rejected before sysfs
access; another heap-stat query still reached all three peers and the system
had no failed units. These results establish startup, memory-heap access and
MPU remote-service communication, not model offload or physical camera capture.

## Sources

- [Pinned TI IPC firmware inventory](https://git.ti.com/cgit/processor-firmware/ti-linux-firmware/tree/WHENCE?id=d528873a75e532075a1fd5d2a53defef98d60437)
  identifies J722S release `REL.MCUSDK.11.02.01.01` and `LICENSE.ti`.
- [TI RPMsg character library](https://git.ti.com/cgit/rpmsg/ti-rpmsg-char/tree/?id=057b1a249261e26d00c501b59646957160ec815b),
  particularly `src/soc.c`, `include/rproc_id.h` and `examples/rpmsg_char_simple.c`.
- [Pinned Armbian J722S memory map](https://github.com/armbian/build/blob/d3298cac2223892b668ab27e95237448eeb75f26/patch/kernel/archive/k3-beagle-6.12/dt/k3-j722s-rtos-memory-map.dtsi).
- [Offline source firmware provenance](accelerator-firmware.md).
