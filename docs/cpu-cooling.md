# CPU frequency and passive cooling

The board device tree supplies one shared A53 frequency policy at 200, 400,
600, 800, 1000 and 1200 MHz. The main0 thermal zone requests CPU cooling at
60°C with 2°C hysteresis; the existing critical trips remain intact.
There are no voltage changes or PMIC programming operations.

This is an adaptation of TI engineer Keerthy's AM67 SDK 11 example from
[TI's AM67 cooling discussion](https://e2e.ti.com/support/processors-group/processors/f/processors-forum/1503848/am67-how-to-change-am67x-cpu-clock-to-1-4ghz).
The linked `cooling-wth-dfs.tar` archive has SHA256
`b601d51b5d054960c9219ebe7dbed8f54eb23ab6c2533d4b3da7f31b8e7bba16`.
Its DTS patch is `91f95cf046fb4ba4002d8c4f5a99fe80614f482c`, authored
15 May 2025, modifying GPL-2.0-only OR MIT device-tree sources.
Original J722S device-tree copyright: Copyright (C) 2024 Texas Instruments
Incorporated — https://www.ti.com/.
The lower five frequencies and passive trip follow that example. Its
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

## Hardware acceptance

The first changed-kernel warm boot verified `cpufreq-dt` policy0 for CPUs
0–3 and all six advertised frequencies. With main0 at approximately 62.7°C,
`cpufreq-cpu0` reported cooling state 5 of 5 and the policy maximum was
200 MHz. This confirms thermal limiting is active. The board was already
warm with its passive heatsink; no controlled stress test or cooldown cycle
was performed. Sustained performance and governor/thermal tuning remain open.

For subsequent acceptance, inspect
`/sys/devices/system/cpu/cpufreq/policy0/`: the affected CPU set must include
all four cores, available frequencies must match the table, and the clock
readback must follow requested frequencies without exceeding 1.2 GHz.
Inspect `/sys/class/thermal/cooling_device*/type`, `cur_state`, and
`max_state`; a `cpufreq-cpu0` device must bind to main0's passive trip.
Observe bounded CPU load with the fitted heatsink, recording clock,
temperature and cooling state as the temperature crosses 60°C and falls
below 58°C. Stop the workload if cooling does not respond. Do not test the
critical shutdown trip by overheating the board.
