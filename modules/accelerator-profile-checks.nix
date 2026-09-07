{
  config,
  lib,
  ...
}: let
  fixture = config.flake.nixosConfigurations.beagley-ai;
  profiles = config.flake.modules.nixos;
  ipc = (fixture.extendModules {modules = [profiles.beagley-ai-remoteproc-ipc];}).config;
  conflictingOwner = builtins.tryEval ((fixture.extendModules {modules = [profiles.beagley-ai-remoteproc-ipc profiles.beagley-ai-vision];}).config.hardware.beagleyAi.remoteprocOwner);
  vision = (fixture.extendModules {modules = [profiles.beagley-ai-vision];}).config;
in {
  perSystem = {pkgs, ...}:
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      checks.accelerator-ipc-dt = assert !conflictingOwner.success; ipc.system.build.beagleyAiAcceleratorDeviceTreeCheck;
      checks.accelerator-vision-dt = vision.system.build.beagleyAiAcceleratorDeviceTreeCheck;
      checks.accelerator-dt-negative =
        pkgs.runCommand "beagley-ai-accelerator-dt-negative" {
          nativeBuildInputs = [pkgs.dtc pkgs.python3];
        } ''
          original=${ipc.hardware.deviceTree.package}/ti/k3-am67a-beagley-ai.dtb
          contract=${ipc.system.build.beagleyAiAcceleratorDeviceTreeCheck}/contract.json
          expect_failure() {
            if python3 ${../packages/accelerator-dt-check.py} bad.dtb "$contract" - > failure.log 2>&1; then
              echo "Invalid accelerator DT was accepted" >&2
              exit 1
            fi
            grep -q "$1" failure.log
          }
          cp "$original" bad.dtb
          chmod u+w bad.dtb
          fdtput -t x bad.dtb /reserved-memory/r5f-dma-memory@a0000000 reg 0 70000000 0 100000
          expect_failure 'outside RAM'
          cp "$original" bad.dtb
          chmod u+w bad.dtb
          fdtput -t x bad.dtb /reserved-memory/r5f-dma-memory@a0000000 reg 0 a0100000 0 100000
          expect_failure 'reservation overlap'
          cp "$original" bad.dtb
          chmod u+w bad.dtb
          fdtput -d bad.dtb /reserved-memory/r5f-memory@a0100000 no-map
          expect_failure 'Device Manager memory mapped'
          mkdir "$out"
        '';
    };
}
