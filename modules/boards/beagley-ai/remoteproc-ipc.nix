{...}: {
  flake.modules.nixos.beagley-ai-remoteproc-ipc = {
    config,
    pkgs,
    ...
  }: {
    imports = [./_remoteproc.nix];
    hardware.beagleyAi.remoteprocOwner = "ipc";
    environment.systemPackages = [(pkgs.callPackage ../../../packages/accelerator-ipc-test.nix {})];
    hardware.firmware = [(pkgs.callPackage ../../../packages/accelerator-ipc-firmware.nix {})];
    system.build.beagleyAiAcceleratorDeviceTreeCheck = pkgs.callPackage ../../../packages/accelerator-dt-check.nix {
      deviceTree = config.hardware.deviceTree.package;
      profile = "ipc";
    };
    system.extraDependencies = [config.system.build.beagleyAiAcceleratorDeviceTreeCheck];
    hardware.deviceTree.overlays = [
      {
        name = "beagley-ai-ipc";
        filter = "k3-am67a-beagley-ai";
        dtsText = ''
          /dts-v1/;
          /plugin/;
          / {
            compatible = "beagle,am67a-beagley-ai";
            fragment@0 {
              target-path = "/bus@f0000/dsp@7e200000";
              __overlay__ { status = "okay"; };
            };
          };
        '';
      }
    ];
  };
}
