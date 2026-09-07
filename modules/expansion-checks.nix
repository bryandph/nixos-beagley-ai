{
  config,
  lib,
  ...
}: let
  fixture = config.flake.nixosConfigurations.beagley-ai;
  profiles = config.flake.modules.nixos;
  extend = names: (fixture.extendModules {modules = map (name: profiles.${name}) names;}).config;
  routed = extend (map (name: "beagley-ai-header-${name}") ["uart1" "i2c-400khz" "spi0" "pwm12" "mcasp0"]);
  gpio = extend ["beagley-ai-header-gpio14-15"];
  pwm = extend ["beagley-ai-header-pwm14"];
  gadget = extend ["beagley-ai-usb-gadget"];
  gadgetConflict =
    (fixture.extendModules {
      modules = [profiles.beagley-ai-usb-gadget {hardware.beagleyAi.resourceClaims."usb:usb0" = ["external-host-owner"];}];
    }).config;
  conflicts = map extend [
    ["beagley-ai-header-gpio14-15" "beagley-ai-header-uart1"]
    ["beagley-ai-header-uart1" "beagley-ai-header-pwm14"]
    ["beagley-ai-header-pwm12" "beagley-ai-oldi-lcd185"]
  ];
in {
  perSystem = {pkgs, ...}:
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      checks.expansion-profiles = assert builtins.all (c: builtins.any (a: !a.assertion) c.assertions) (conflicts ++ [gadgetConflict]);
        pkgs.runCommand "beagley-ai-expansion-profiles" {nativeBuildInputs = [pkgs.dtc];} ''
          mkdir "$out"
          cp ${routed.hardware.deviceTree.package}/ti/k3-am67a-beagley-ai.dtb "$out/routed.dtb"
          cp ${gpio.hardware.deviceTree.package}/ti/k3-am67a-beagley-ai.dtb "$out/gpio.dtb"
          cp ${pwm.hardware.deviceTree.package}/ti/k3-am67a-beagley-ai.dtb "$out/pwm.dtb"
          cp ${gadget.hardware.deviceTree.package}/ti/k3-am67a-beagley-ai.dtb "$out/gadget.dtb"
          for symbol in main_uart1 mcu_spi0 mcasp0 ecap0; do
            node=$(fdtget -t s "$out/routed.dtb" /__symbols__ "$symbol")
            test "$(fdtget -t s "$out/routed.dtb" "$node" status)" = okay
          done
          node=$(fdtget -t s "$out/routed.dtb" /__symbols__ mcu_i2c0)
          test "$(fdtget -t u "$out/routed.dtb" "$node" clock-frequency)" = 400000
          node=$(fdtget -t s "$out/gpio.dtb" /__symbols__ main_uart1)
          test "$(fdtget -t s "$out/gpio.dtb" "$node" status)" = disabled
          node=$(fdtget -t s "$out/gadget.dtb" /__symbols__ usb0)
          test "$(fdtget -t s "$out/gadget.dtb" "$node" dr_mode)" = peripheral
          echo ${gadget.systemd.services.beagley-usb-gadget.serviceConfig.ExecStart} > "$out/gadget-command"
        '';
    };
}
