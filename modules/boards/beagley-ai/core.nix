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
