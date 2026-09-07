# Real-time clocks

BeagleY-AI has an external DS1340 on I2C and a separate TI K3 internal RTC.
The board's base DT assigns `rtc0` to the DS1340. Linux 6.12 allocates an
unaliased RTC the first free number, so the earlier-probed internal RTC could
take that number and force the DS1340 to `rtc1`. The core module's board DT
overlay assigns `rtc1` explicitly to the internal RTC, preserving `rtc0` for
the DS1340 regardless of their probe order.

Identify each clock before initialization; a previous kernel generation can
have different numbering:

```sh
for rtc in /sys/class/rtc/rtc*; do
  printf '%s: ' "$rtc"
  cat "$rtc/name"
done
```

The external clock's driver name is `rtc-ds1307`, despite the chip being a
DS1340. Its DT node is `rtc@68` under I2C controller `i2c@2b200000`.
The internal clock is `rtc-ti-k3` at `rtc@2b1f0000`.

## Initialize from synchronized system time

A first read can fail with `Invalid argument` when the oscillator-stop flag
is set or the calendar has not been initialized. This is not by itself an
I2C communication failure. Confirm NTP synchronization first:

```sh
timedatectl show -p NTPSynchronized --value
```

Only after this reports `yes`, write the system time to the identified
DS1340 (normally `/dev/rtc0` with the BSP overlay):

```sh
sudo hwclock --systohc --utc --rtc /dev/rtc0
sudo hwclock --show --utc --rtc /dev/rtc0
```

The kernel's DS1340 set-time operation clears the oscillator-stop flag and
enables the oscillator through the normal RTC interface. No raw I2C register
writes or PMIC programming are needed. The pinned driver does not implement
`RTC_VL_READ`; `hwclock --vl-read` returning `Inappropriate ioctl for device`
does not diagnose a bad battery.

## Retention and limits

RTC initialization and readback passed on the board. No backup battery is
fitted. The operator waived battery-backed retention testing, so RTC
implementation is complete with retention explicitly unverified. The changed-kernel warm boot verified the external DS1340 as `rtc0`,
with valid time available during boot, and the internal RTC as `rtc1`.
The internal clock still reported an epoch value and is not accepted as a
time source.
The board provides a two-pin JST SH connector with 1 mm pitch for backup
power. Leave trickle charging unconfigured unless the fitted backup source
has explicitly been identified as rechargeable and its limits are known.

The observed internal RTC clock-rate warning is separate from DS1340
initialization. Making the external RTC primary does not fix or validate the
internal oscillator's accuracy.

## Sources

- [BeagleBoard RTC guide](https://docs.beagleboard.org/boards/beagley/ai/demos/using-rtc.html)
  identifies the chip, battery connector and initialization requirement.
- [DS1340 datasheet](https://www.analog.com/media/en/technical-documentation/data-sheets/DS1340-DS1340C.pdf)
  defines oscillator control, the sticky oscillator-stop flag and charging.
- Pinned Linux [RTC ID allocation](https://github.com/beagleboard/linux/blob/8fb21420a704ea36aaf66df8288ed8ee9da2762d/drivers/rtc/class.c)
  and [DS1340 read/set-time implementation](https://github.com/beagleboard/linux/blob/8fb21420a704ea36aaf66df8288ed8ee9da2762d/drivers/rtc/rtc-ds1307.c).
