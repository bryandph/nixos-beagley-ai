# CC3301 Wi-Fi and Bluetooth LE

Import `nixosModules.beagley-ai-wireless` alongside the consumer's network
policy. It provides the matched firmware, SDIO and UART drivers, Bluetooth
daemon and CC33xx BLE initialization service. It does not select an SSID,
store credentials, change Ethernet configuration or automatically power on
Bluetooth for discovery. Configure the regulatory domain and Wi-Fi connection
through the consumer's normal networking module.

The board uses a CC3301: 2.4 GHz Wi-Fi and Bluetooth LE. It does not provide
5 GHz Wi-Fi or Bluetooth Classic. The shared SDK configuration includes a
5 GHz capability flag for the wider CC33xx family; the pinned driver also
checks the chip's hardware `disable_5g` value before advertising that band.
The package preserves the vendor configuration without editing firmware bytes.

## Frozen tuple

`packages/wireless-release.nix` owns the URLs, sizes, hashes and ABI evidence:

- Kernel driver: BeagleBoard `8fb21420a704ea36aaf66df8288ed8ee9da2762d`.
- CC33xx SDK 1.0.2.10, firmware/configuration 1.7.0.316, from the official
  BeagleBoard firmware package at its pinned repository revision.
- Three files installed under `lib/firmware/ti-connectivity`:
  `cc33xx_2nd_loader.bin`, `cc33xx_fw.bin`, `cc33xx-conf.bin`.
- The configuration is 1282 bytes, matching the packed kernel structure;
  its header, BLE enable, 115200 baud and hardware flow-control fields are
  checked during the package build.

TI processor firmware release 11.02.15 contains older CC33xx 1.7.0.120
firmware and a different configuration layout. Sharing a processor SDK
release name does not make those wireless binaries match this kernel.

The publisher's Debian package depends on `firmware-ti-connectivity`, which
provides the TI connectivity license. This package preserves the unmodified
`LICENCE.ti-connectivity` notice from the pinned linux-firmware release.
Redistribution is restricted to TI devices and unmodified binary software.

## Bluetooth transport

The board DT routes Bluetooth to `main_uart6`, with a `ti,cc33xx-bt` child,
115200 baud, RTS/CTS and the shared `wlan_en` supply. Linux's `btti_uart`
serdev driver owns this UART. The SDIO driver downloads firmware for both
radios; this transport does not request a separate `.bts` service pack and
must not be paired with a competing `hciattach` process.

The downstream driver exposes a CC33xx-specific `ble_enable` debugfs file.
The module's bounded initialization service enables that control after the
SDIO firmware has initialized. It leaves BlueZ automatic power-on disabled.
Optional `cc33xx-nvs.bin` board data is not fabricated or copied from another
board; the driver supports its absence.

The transport requires `BT_LE=y`, `CFG80211_DEBUGFS=y` and
`MAC80211_DEBUGFS=y` in the generated kernel configuration. Selecting the
CC33xx modules alone does not select those dependencies. The composed host's
`config.system.build.beagleyAiWirelessCheck` checks these and the required
serdev and wireless modules against the actual kernel configuration.

## Acceptance

Package build and configuration ABI checks pass. Physical Wi-Fi association,
reconnection and traffic, and Bluetooth LE discovery/GATT require identified
network and peer fixtures and remain unverified. After deployment inspect
`journalctl -k`, `iw phy`, `rfkill list`, `bluetoothctl list` and
`systemctl status beagley-ai-bluetooth-init`. Firmware load or HCI enumeration
alone does not establish radio data-path acceptance. Keep Ethernet available
throughout wireless bring-up.

## Sources

- [BeagleBoard SDK firmware package](https://github.com/beagleboard/repos-arm64/tree/fb0f6eccb2928b6e9d6c0dca5782f45939e85ae4/bbb.io-cc33xx-1.0.2.10-firmware)
  includes its Debian dependency on the TI connectivity license package.
- [Pinned kernel configuration ABI](https://github.com/beagleboard/linux/blob/8fb21420a704ea36aaf66df8288ed8ee9da2762d/drivers/net/wireless/ti/cc33xx/conf.h),
  [SDIO initialization](https://github.com/beagleboard/linux/blob/8fb21420a704ea36aaf66df8288ed8ee9da2762d/drivers/net/wireless/ti/cc33xx/main.c),
  and [UART Bluetooth transport](https://github.com/beagleboard/linux/blob/8fb21420a704ea36aaf66df8288ed8ee9da2762d/drivers/bluetooth/btti_uart.c).
- [TI CC33xx port recipes](https://github.com/TexasInstruments-Sandbox/cc33xx-linux-mpu-ports/tree/01acc04804da478c64cb52c0069978fd94b6ac60)
  and [TI Bluetooth initialization discussion](https://e2e.ti.com/support/wireless-connectivity/wi-fi-group/wifi/f/wi-fi-forum/1560711/am62l-processor-sdk-cc33xx-bluetooth-module-functionality-issue).
