{
  config,
  lib,
  ...
}: let
  fixture = config.flake.nixosConfigurations.beagley-ai-full;
  full = fixture.config;
  profiles = config.flake.modules.nixos;
  dualCamera = (fixture.extendModules {modules = [profiles.beagley-ai-csi0-imx219 profiles.beagley-ai-csi1-imx219];}).config;
  cameraDisplay = (fixture.extendModules {modules = [profiles.beagley-ai-csi0-imx219 profiles.beagley-ai-dsi-rpi-7inch];}).config;
  connectorConflict = (fixture.extendModules {modules = [profiles.beagley-ai-csi1-imx219 profiles.beagley-ai-dsi-rpi-7inch];}).config;
  ownerConflict = (fixture.extendModules {modules = [profiles.beagley-ai-remoteproc-ipc];}).config;
  packageNames = map lib.getName full.environment.systemPackages;
in {
  perSystem = {pkgs, ...}:
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      checks.full-feature-system = full.system.build.toplevel;
      checks.full-feature-composition = assert full.hardware.beagleyAi.remoteprocOwner == "vision";
      assert full.hardware.graphics.enable;
      assert !(full.systemd.services.beagley-ai-remoteproc.serviceConfig ? ExecStop);
      assert builtins.hasAttr "beagley-ai-bluetooth-init" full.systemd.services;
      assert builtins.all (name: builtins.elem name packageNames) ["beagley-ai-accelerator-runtime" "beagley-ai-tidl" "beagley-ai-osrt" "beagley-ai-camera"];
      assert builtins.all (a: a.assertion) full.assertions;
      assert builtins.all (a: a.assertion) dualCamera.assertions;
      assert builtins.all (a: a.assertion) cameraDisplay.assertions;
      assert builtins.any (a: !a.assertion) connectorConflict.assertions;
      assert !(builtins.tryEval ownerConflict.hardware.beagleyAi.remoteprocOwner).success;
      assert !(builtins.any (overlay: builtins.elem overlay.name ["beagley-ai-csi0-imx219" "beagley-ai-csi1-imx219" "beagley-ai-dsi-rpi-7inch" "beagley-ai-oldi-lcd185"]) full.hardware.deviceTree.overlays);
        pkgs.runCommand "beagley-ai-full-feature-composition" {nativeBuildInputs = [pkgs.dtc];} ''
          mkdir "$out"
          # These check the final trees after all features and connector alternatives.
          cp ${full.system.build.beagleyAiAcceleratorDeviceTreeCheck}/contract.json "$out/default-contract.json"
          cp ${dualCamera.system.build.beagleyAiAcceleratorDeviceTreeCheck}/contract.json "$out/dual-camera-contract.json"
          cp ${cameraDisplay.system.build.beagleyAiAcceleratorDeviceTreeCheck}/contract.json "$out/camera-display-contract.json"
          test -e ${full.system.build.beagleyAiAcceleratorKernelCheck}
          test -e ${full.system.build.beagleyAiWirelessCheck}
          for symbol in imx219_0 imx219_1; do
            node=$(fdtget -t s ${dualCamera.hardware.deviceTree.package}/ti/k3-am67a-beagley-ai.dtb /__symbols__ "$symbol")
            test "$(fdtget -t s ${dualCamera.hardware.deviceTree.package}/ti/k3-am67a-beagley-ai.dtb "$node" compatible)" = sony,imx219
          done
          test "$(fdtget -t s ${cameraDisplay.hardware.deviceTree.package}/ti/k3-am67a-beagley-ai.dtb /panel0 compatible)" = 'raspberrypi,7inch-dsi simple-panel'
          echo ${builtins.unsafeDiscardStringContext full.system.build.toplevel.drvPath} > "$out/system.drv"
        '';
    };
}
