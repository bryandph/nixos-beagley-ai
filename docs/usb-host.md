# USB host reset ownership

The USB-A ports use one physical TI hub with USB2 (`0451:8142`) and USB3
(`0451:8140`) peers. Both DT nodes describe the same active-low reset GPIO,
`main_gpio0` line 32. Their reciprocal `peer-hub` properties let Linux create
one platform device to own the shared reset and supplies; the duplicate GPIO
description does not mean that two independent drivers should toggle it.

The vendor configuration builds `USB_ONBOARD_DEV` as a module while the host
controller, GPIO and pin controller are built in. The original BSP initrd did
not include that module. In the pinned driver, platform probe requests the
reset GPIO with `GPIOD_OUT_HIGH` (asserted for an active-low reset), then
releases it in `onboard_dev_power_on()`. Loading the module after USB
enumeration can therefore reset an already operating hub. Repeated interface
probing can also occur while the USB device driver waits for its platform
driver to finish probing.

The BSP builds `USB_ONBOARD_DEV` into the kernel to establish reset ownership
during kernel initialization. This is a mitigation for late module loading;
it does not by itself prove that every controller/platform probe ordering
race is eliminated. Keep the shared reset description and peer relationship.

Before this change, boot observations included repeated hub discovery,
configuration failures (`-71` or `-110`), disconnects, then successful
enumeration of both four-port hubs at 480 and 5000 Mbit/s. A captured boot
confirmed that the USB2 hub enumerated before `onboard-usb-dev` registered,
followed by repeated probes and both peers disconnecting. The running kernel
configuration also confirmed the module/built-in split above. Hub enumeration
alone does not validate attached peripherals.

## Acceptance

The first changed-kernel warm boot registered `onboard-usb-dev` at about
1.18 seconds, before hub discovery at about 23 seconds. Both peers enumerated
at 480 and 5000 Mbit/s without the earlier disconnect/configuration errors.
This passes one boot observation; attached peripherals and repeated warm/cold
boots remain unverified.

For further acceptance:

- Verify `CONFIG_USB_ONBOARD_DEV=y` in the running kernel configuration.
- Inspect the complete boot log for hub disconnects, repeated discovery,
  configuration failures and deferred platform probes.
- Verify both TI identities, negotiated speeds and hub interface binding in
  sysfs. An optional USB `product` string is not an enumeration requirement.
- Repeat warm boots and a cold boot, then test identified USB2 and USB3
  peripherals with actual traffic. Use disposable media for any write test.

Do not unbind the hub or toggle its reset while a USB storage device is in
use. Record runtime results in the hardware coverage matrix; this document
explains the implementation and its limits.

## Sources

- Pinned Linux [platform probe and power sequence](https://github.com/beagleboard/linux/blob/8fb21420a704ea36aaf66df8288ed8ee9da2762d/drivers/usb/misc/onboard_usb_dev.c),
  and [peer platform-device ownership](https://github.com/beagleboard/linux/blob/8fb21420a704ea36aaf66df8288ed8ee9da2762d/drivers/usb/misc/onboard_usb_dev_pdevs.c).
- Pinned [vendor configuration](https://github.com/armbian/build/blob/d3298cac2223892b668ab27e95237448eeb75f26/config/kernel/linux-k3-beagle-vendor.config).
- Debian kernel maintainers [document late module loading resetting already
  mounted USB devices](https://salsa.debian.org/kernel-team/linux/-/merge_requests/1302)
  and include the driver in their installer initramfs. That report establishes
  the failure mechanism on other boards, not physical acceptance on BeagleY-AI.
