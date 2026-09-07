{
  config,
  inputs,
  lib,
  ...
}: {
  flake.nixosConfigurations.beagley-ai = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      config.flake.modules.nixos.beagley-ai-core
      config.flake.modules.nixos.beagley-ai-sd-image
      ({lib, ...}: {
        networking = {
          hostName = "beagley-ai";
          useDHCP = lib.mkDefault true;
        };
        # Public fixture has a local serial login, no credentials or SSH keys.
        services.getty.autologinUser = "root";
        services.openssh.enable = false;
        nixpkgs.config.allowUnfreePredicate = pkg:
          builtins.elem (lib.getName pkg) [
            "beagley-ai-boot-firmware"
            "beagley-ai-uboot-r5"
            "beagley-ai-uboot-a53"
            "beagley-ai-boot-bundle"
          ];
        image.baseName = "nixos-beagley-ai";
        system.stateVersion = "26.05";
      })
    ];
  };
  perSystem = {system, ...}:
    lib.mkIf (system == "aarch64-linux") {
      packages.beagley-ai-sd-image = config.flake.nixosConfigurations.beagley-ai.config.system.build.beagleyAiSdImage;
    };
}
