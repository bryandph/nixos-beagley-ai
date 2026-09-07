{config, ...}: {
  flake.nixosModules = {
    inherit (config.flake.modules.nixos) beagley-ai-core beagley-ai-sd-image;
  };
}
