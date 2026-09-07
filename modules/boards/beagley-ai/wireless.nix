{...}: {
  flake.modules.nixos.beagley-ai-wireless = {
    config,
    pkgs,
    ...
  }: {
    system.build.beagleyAiWirelessCheck = pkgs.callPackage ../../../packages/wireless-check.nix {
      kernel = config.boot.kernelPackages.kernel;
    };
    hardware.firmware = [
      (pkgs.callPackage ../../../packages/wireless-firmware.nix {})
    ];
    # Register the UART listener before SDIO downloads the shared firmware.
    boot.kernelModules = ["btti_uart" "cc33xx_sdio"];
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = false;
    };
    environment.systemPackages = [pkgs.iw pkgs.bluez];
    systemd.services.beagley-ai-bluetooth-init = {
      description = "Enable CC3301 Bluetooth in the shared SDIO firmware";
      wantedBy = ["multi-user.target"];
      after = ["systemd-modules-load.service" "sys-kernel-debug.mount"];
      requires = ["sys-kernel-debug.mount"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 35;
      };
      script = ''
        # The downstream firmware exposes BLE through this CC33xx-only control.
        # Do not bind a generic hciattach process to its serdev-owned UART.
        for attempt in $(seq 1 30); do
          for control in /sys/kernel/debug/ieee80211/phy*/cc33xx/ble_enable; do
            if test -f "$control"; then
              if test "$(cat "$control")" != 1; then
                printf '1\n' > "$control"
              fi
              test "$(cat "$control")" = 1
              exit 0
            fi
          done
          sleep 1
        done
        echo "CC3301 firmware did not expose its BLE control" >&2
        exit 1
      '';
    };
  };
}
