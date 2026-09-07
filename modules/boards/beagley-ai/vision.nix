{
  config,
  lib,
  ...
}: let
  firmware = config.flake.packages.x86_64-linux.beagley-ai-accelerator-firmware;
  regions = import ../../../packages/accelerator-memory.nix;
in {
  flake.modules.nixos.beagley-ai-vision = {
    config,
    pkgs,
    ...
  }: {
    imports = [./_remoteproc.nix];
    hardware.beagleyAi.remoteprocOwner = "vision";
    hardware.firmware = [firmware];
    system.build.beagleyAiAcceleratorDeviceTreeCheck = pkgs.callPackage ../../../packages/accelerator-dt-check.nix {
      deviceTree = config.hardware.deviceTree.package;
      profile = "vision";
      inherit firmware;
    };
    system.extraDependencies = [config.system.build.beagleyAiAcceleratorDeviceTreeCheck];
    hardware.deviceTree.overlays = [
      {
        name = "beagley-ai-vision";
        filter = "k3-am67a-beagley-ai";
        dtsText = ''
          /dts-v1/;
          /plugin/;
          / {
            compatible = "beagle,am67a-beagley-ai";
            fragment@0 {
              target-path = "/reserved-memory";
              __overlay__ {
                #address-cells = <2>;
                #size-cells = <2>;
                linux,cma { status = "disabled"; };
                ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: region: ''
              ${name} {
                compatible = "${region.compatible or "shared-dma-pool"}";
                reg = <${lib.concatStringsSep " " region.reg}>;
                ${lib.optionalString (region.noMap or true) "no-map;"}
                ${lib.optionalString (region.cma or false) "reusable; linux,cma-default;"}
              };
            '')
            regions)}
              };
            };
            fragment@1 {
              target-path = "/bus@f0000/dsp@7e200000";
              __overlay__ { status = "okay"; };
            };
          };
        '';
      }
    ];
  };
}
