{...}: {
  flake.modules.nixos.beagley-ai-core = {
    config,
    lib,
    pkgs,
    ...
  }: let
    release = import ../../../packages/release.nix;
    kernel = pkgs.callPackage ../../../packages/linux.nix {};
  in {
    nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
    boot = {
      kernelPackages = lib.mkDefault (pkgs.linuxPackagesFor kernel);
      kernelParams = ["console=${release.board.console}" "earlycon" "rootwait"];
      supportedFilesystems = lib.mkForce ["ext4" "vfat"];
      initrd.includeDefaultModules = false;
      initrd.systemd.tpm2.enable = lib.mkDefault false;
      initrd.availableKernelModules = ["mmc_block" "sdhci" "sdhci_am654"];
      loader = {
        grub.enable = false;
        generic-extlinux-compatible = {
          enable = true;
          configurationLimit = 5;
        };
      };
    };
    hardware.deviceTree = {
      enable = true;
      name = release.board.dtb;
      filter = "k3-am67a-beagley-ai*.dtb";
      overlays = [
        {
          name = "beagley-ai-rtc-order";
          filter = "k3-am67a-beagley-ai";
          # RTC aliases are not reserved globally. Give the early-probed
          # internal RTC an explicit ID so it cannot take the DS1340's rtc0.
          dtsText = ''
            /dts-v1/;
            /plugin/;
            / {
              compatible = "beagle,am67a-beagley-ai";
              fragment@0 {
                target-path = "/aliases";
                __overlay__ {
                  rtc1 = "/bus@f0000/bus@b00000/rtc@2b1f0000";
                };
              };
            };
          '';
        }
      ];
    };
    system.build.beagleyAiDeviceTreeCheck = pkgs.callPackage ../../../packages/device-tree-check.nix {
      deviceTree = config.hardware.deviceTree.package;
    };
    assertions = [
      {
        assertion = (config.boot.kernelPackages.kernel.provider or null) == release.provider;
        message = "BeagleY-AI requires the coordinated board kernel/DT/firmware provider.";
      }
      {
        assertion = config.hardware.deviceTree.name == release.board.dtb;
        message = "BeagleY-AI must use its matching board DTB.";
      }
    ];
  };
}
