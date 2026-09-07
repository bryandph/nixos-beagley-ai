{lib, ...}: {
  perSystem = {pkgs, ...}:
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      packages.beagley-ai-codec-firmware = pkgs.callPackage ../packages/multimedia-firmware.nix {};
      packages.beagley-ai-pvr-mesa = pkgs.pkgsCross.aarch64-multiplatform.callPackage ../packages/multimedia-mesa.nix {};
      packages.beagley-ai-rogue-userspace = pkgs.pkgsCross.aarch64-multiplatform.callPackage ../packages/multimedia-rogue-userspace.nix {};
      packages.beagley-ai-rogue-kmod = pkgs.pkgsCross.aarch64-multiplatform.callPackage ../packages/multimedia-rogue-kmod.nix {
        kernel = pkgs.pkgsCross.aarch64-multiplatform.callPackage ../packages/linux.nix {};
      };
    };
  flake.modules.nixos.beagley-ai-multimedia = {pkgs, ...}: {
    hardware.firmware = [(pkgs.callPackage ../packages/multimedia-firmware.nix {})];
    environment.systemPackages = [(pkgs.v4l-utils.override {withGUI = false;}) pkgs.ffmpeg];
  };
  flake.modules.nixos.beagley-ai-gpu = {
    config,
    pkgs,
    ...
  }: let
    userspace = pkgs.callPackage ../packages/multimedia-rogue-userspace.nix {};
    mesa = pkgs.callPackage ../packages/multimedia-mesa.nix {};
  in {
    boot.extraModulePackages = [(config.boot.kernelPackages.callPackage ../packages/multimedia-rogue-kmod.nix {})];
    boot.kernelModules = ["pvrsrvkm"];
    hardware.firmware = [userspace];
    hardware.graphics = {
      enable = true;
      package = mesa;
      extraPackages = [userspace];
    };
    environment.systemPackages = [userspace pkgs.clinfo pkgs.vulkan-tools pkgs.mesa-demos pkgs.alsa-utils];
  };
}
