{
  config,
  lib,
  ...
}: let
  fixture = config.flake.nixosConfigurations.beagley-ai;
  profiles = config.flake.modules.nixos;
  cameras = (fixture.extendModules {modules = [profiles.beagley-ai-csi0-imx219 profiles.beagley-ai-csi1-imx219];}).config;
  display = (fixture.extendModules {modules = [profiles.beagley-ai-csi0-imx219 profiles.beagley-ai-dsi-rpi-7inch];}).config;
  conflict = (fixture.extendModules {modules = [profiles.beagley-ai-csi1-imx219 profiles.beagley-ai-dsi-rpi-7inch];}).config;
  oldi = (fixture.extendModules {modules = [profiles.beagley-ai-oldi-lcd185 profiles.beagley-ai-dsi-rpi-7inch];}).config;
  oldiConflict = (fixture.extendModules {modules = [profiles.beagley-ai-oldi-lcd185 profiles.beagley-ai-header-pwm12];}).config;
in {
  perSystem = {pkgs, ...}:
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      checks.media-profiles = assert builtins.any (a: !a.assertion) conflict.assertions;
      assert builtins.any (a: !a.assertion) oldiConflict.assertions;
        pkgs.runCommand "beagley-ai-media-profiles" {nativeBuildInputs = [pkgs.dtc];} ''
          mkdir "$out"
          cp ${cameras.hardware.deviceTree.package}/ti/k3-am67a-beagley-ai.dtb "$out/dual-camera.dtb"
          cp ${display.hardware.deviceTree.package}/ti/k3-am67a-beagley-ai.dtb "$out/camera-and-dsi.dtb"
          cp ${oldi.hardware.deviceTree.package}/ti/k3-am67a-beagley-ai.dtb "$out/oldi-and-dsi.dtb"
          for symbol in imx219_0 imx219_1; do
            node=$(fdtget -t s "$out/dual-camera.dtb" /__symbols__ "$symbol")
            test "$(fdtget -t s "$out/dual-camera.dtb" "$node" compatible)" = sony,imx219
          done
          test "$(fdtget -t s "$out/camera-and-dsi.dtb" /panel0 compatible)" = 'raspberrypi,7inch-dsi simple-panel'
          node=$(fdtget -t s "$out/camera-and-dsi.dtb" /__symbols__ dsi0)
          test "$(fdtget -t s "$out/camera-and-dsi.dtb" "$node" status)" = okay
          test "$(fdtget -t s "$out/oldi-and-dsi.dtb" /lcd compatible)" = 'lincolntech,lcd185-101ct panel-simple'
        '';
    };
}
