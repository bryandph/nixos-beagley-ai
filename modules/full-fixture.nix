{
  config,
  inputs,
  lib,
  ...
}: {
  flake.nixosConfigurations.beagley-ai-full = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      config.flake.modules.nixos.beagley-ai-full
      config.flake.modules.nixos.beagley-ai-sd-image
      ({lib, ...}: {
        networking.hostName = "beagley-ai";
        networking.useDHCP = lib.mkDefault true;
        services.getty.autologinUser = "root";
        services.openssh.enable = false;
        nixpkgs.config.allowUnfreePredicate = pkg:
          builtins.elem (lib.getName pkg) [
            "beagley-ai-boot-firmware"
            "beagley-ai-uboot-r5"
            "beagley-ai-uboot-a53"
            "beagley-ai-boot-bundle"
            "beagley-ai-codec-firmware"
            "beagley-ai-rogue-userspace"
            "beagley-ai-wireless-firmware"
            "beagley-ai-accelerator-firmware"
            "beagley-ai-accelerator-runtime"
            "beagley-ai-tidl"
            "beagley-ai-osrt"
            "beagley-ai-edgeai-libraries"
            "beagley-ai-edgeai-gstreamer"
            "beagley-ai-imx219-dcc"
          ];
        image.baseName = "nixos-beagley-ai-full";
        system.stateVersion = "26.05";
      })
    ];
  };
  perSystem = {system, ...}:
    lib.mkIf (system == "aarch64-linux") {
      packages.beagley-ai-full-sd-image = config.flake.nixosConfigurations.beagley-ai-full.config.system.build.beagleyAiSdImage;
    };
}
