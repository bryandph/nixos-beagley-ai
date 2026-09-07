{
  config,
  lib,
  ...
}: {
  perSystem = {system, ...}:
    lib.mkIf (system == "aarch64-linux") {
      checks.sd-image-layout = config.flake.nixosConfigurations.beagley-ai.config.system.build.beagleyAiSdImageCheck;
    };
}
