# CPU frequency and passive cooling

The board device tree supplies one shared A53 frequency policy at 200, 400,
600, 800, 1000 and 1200 MHz. The main0 thermal zone requests CPU cooling at
85°C with 5°C hysteresis; the existing critical trips remain intact.
There are no voltage changes or PMIC programming operations.

This is an adaptation of TI engineer Keerthy's AM67 SDK 11 example from
[TI's AM67 cooling discussion](https://e2e.ti.com/support/processors-group/processors/f/processors-forum/1503848/am67-how-to-change-am67x-cpu-clock-to-1-4ghz).
The linked `cooling-wth-dfs.tar` archive has SHA256
`b601d51b5d054960c9219ebe7dbed8f54eb23ab6c2533d4b3da7f31b8e7bba16`.
Its DTS patch is `91f95cf046fb4ba4002d8c4f5a99fe80614f482c`, authored
15 May 2025, modifying GPL-2.0-only OR MIT device-tree sources.
Original J722S device-tree copyright: Copyright (C) 2024 Texas Instruments
Incorporated — https://www.ti.com/.
The lower five frequencies follow that example. Its
1.4 GHz EVM maximum is replaced by BeagleY-AI's 1.2 GHz boot frequency,
specified in the pinned U-Boot `arch/arm/dts/k3-am67a-r5-beagley-ai.dts`
and confirmed in the running board's `clk:135:0` through `clk:138:0`.

The include is board-specific: it does not add cooling references to the
thermal file shared by unrelated AM62P boards. Linux 6.12's `cpufreq-dt`
already registers a cooling device through `CPUFREQ_IS_COOLING_DEV`, and
the thermal core computes a trend when the sensor driver supplies none.
Consequently the example's separate bandgap driver patch is unnecessary.
TI also confirms that the missing OPP table explains absent cpufreq sysfs
on BeagleY-AI in its [DFS support discussion](https://e2e.ti.com/support/processors-group/processors/f/processors-forum/1585634/am67a-support-of-dfs).

## Board thermal policy

The AM67x datasheet (SPRSPA3B, section 6.3 Recommended Operating Conditions)
specifies a maximum operating junction temperature of 125°C, matching the
vendor critical trips. The BSP uses an engineering policy of 85°C passive
throttling, providing 40°C of margin, with 5°C hysteresis. These values are
not a TI recommendation or a guarantee for every enclosure and workload.
See the [TI datasheet](https://www.ti.com/lit/ds/symlink/am67a.pdf).

The original TI demonstration threshold of 60°C was below the measured
64–67°C temperature of this board at idle with its passive heatsink. It
therefore continuously limited all CPUs to 200 MHz. Raising the passive
threshold preserves thermal protection while allowing normal server
performance. CPU voltage and the 1.2 GHz maximum are unchanged.

## Hardware acceptance

The initial 60°C-policy kernel warm boot verified `cpufreq-dt` policy0 for CPUs
0–3 and all six advertised frequencies. With main0 at approximately 62.7°C,
`cpufreq-cpu0` reported cooling state 5 of 5 and the policy maximum was
200 MHz. This confirms thermal limiting is active. The board was already
warm with its passive heatsink; no controlled stress test or cooldown cycle
was performed. The revised 85°C policy booted successfully: policy maximum returned to 1200 MHz
at an observed 63.7°C, removing the idle cap. A subsequent 45-second four-process
SHA-256 workload held 1.2 GHz and reached a peak of 69.717°C with the fitted
heatsink and no fan. This passes bounded load acceptance; long-duration
performance, an observed 85°C trip/cooldown cycle and physical fan tests remain open.

For subsequent acceptance, inspect
`/sys/devices/system/cpu/cpufreq/policy0/`: the affected CPU set must include
all four cores, available frequencies must match the table, and the clock
readback must follow requested frequencies without exceeding 1.2 GHz.
Inspect `/sys/class/thermal/cooling_device*/type`, `cur_state`, and
`max_state`; a `cpufreq-cpu0` device must bind to main0's passive trip.
Observe bounded CPU load with the fitted heatsink, recording clock,
temperature and cooling state. Use at most 30 seconds initially and stop at
95°C, below the unchanged critical trip. A cooldown cycle should release
thermal limiting below 80°C; crossing 85°C is not required to pass a basic
load/frequency test. Stop the workload if cooling does not respond. Do not test the
critical shutdown trip by overheating the board.


## Idle and suspend capability

The kernel enables CPU idle and PSCI idle support. However, the pinned J722S
DT describes no CPU suspend states, and the running firmware reports
`PSCI_FEATURES(CPU_SUSPEND) error (-1)` (`NOT_SUPPORTED`). Its supported
function list also omits `SYSTEM_SUSPEND`. The selected TF-A
[`k3_psci.c`](https://github.com/TexasInstruments/arm-trusted-firmware/blob/b11beb2b6bd30b75c4bfb0e9925c0e72f16ca53f/plat/ti/k3/common/k3_psci.c)
disables suspend operations when system firmware advertises none of its
recognized low-power capabilities. Adding made-up DT state IDs cannot fix
this firmware limitation. Deeper CPU idle and platform suspend remain
blocked on a compatible firmware capability and matching DT state contract.
Do not replace or stop the system Device Manager to test an unrelated image.

The arm64 default idle path still executes WFI (wait for interrupt); absence
of a registered cpuidle driver does not imply that idle CPUs busy-loop. WFI
is baseline architecture behavior, not verified platform power gating.
Read capability and mode information without initiating suspend:

```sh
cat /sys/kernel/debug/psci
cat /sys/devices/system/cpu/cpuidle/current_driver
cat /sys/power/mem_sleep
```

The observed values are `none` for the idle driver and `[s2idle]` for memory
sleep. The presence of `mem` in `/sys/power/state` does not establish deep
suspend support; suspend-to-idle and resume have not been physically tested.

## Watchdog, LEDs, button and fan

`WATCHDOG_SYSFS` exposes watchdog identity and state without opening a device
node (which can arm a watchdog). Identify each instance first:

```sh
for wd in /sys/class/watchdog/watchdog*; do
  printf '%s\n' "$wd"
  cat "$wd/identity" "$wd/state" "$wd/nowayout"
done
```

Do not blindly open every `/dev/watchdog*`; ownership and reset/recovery
acceptance must be established for a selected instance before arming it.
All five currently enumerated instances bind to `rti-wdt`. Its pinned
driver sets `nowayout` and has no stop operation, so closing the device is
not a reliable way to undo an armed watchdog. Use an attended reset test
with recovery available, not an exploratory open/read.

The board exposes `ACT` and `PWR` through `/sys/class/leds/`; read their
`brightness`, `max_brightness` and `trigger` attributes. The observed ACT
trigger is heartbeat. To test an LED during an attended session, save its
active trigger and brightness, select `none`, toggle brightness between 0
and its maximum, then restore the saved settings. Electrical writes alone
do not verify visible output; that still requires an observer.

The power button is the TPS65219 PMIC input device
`tps65219-pwrbutton`, exposed as `KEY_POWER` (observed at `/dev/input/event0`).
Identify it in `/proc/bus/input/devices` before monitoring it with `evtest`.
The normal system power policy can shut down the board on a press; a button
press is not a harmless GPIO test. Prior orderly shutdown and reboot were
observed; no raw PMIC access is needed.

The fan driver exposes a hwmon device named `pwmfan` and `pwm1` controls.
Discover it by reading `/sys/class/hwmon/hwmon*/name`; do not assume its
numeric hwmon ID. The vendor thermal zones already request its PWM cooling
levels. No fan is fitted to the current test board, so fan rotation and
thermal effectiveness remain unverified, not waived. Leave its normal
thermal control in place until an identified fan is available.
