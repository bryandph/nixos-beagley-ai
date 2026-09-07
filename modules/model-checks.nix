{
  config,
  lib,
  ...
}: let
  consumer =
    (config.flake.nixosConfigurations.beagley-ai.extendModules {
      modules = [config.flake.modules.nixos.beagley-ai-regnet-model];
    }).config;
  model = config.flake.packages.x86_64-linux.beagley-ai-regnet-model;
in {
  perSystem = {pkgs, ...}:
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      checks.model-profile = assert builtins.elem "/share/beagley-ai/models" consumer.environment.pathsToLink;
      assert builtins.any (package: lib.getName package == "beagley-ai-regnet-model") consumer.environment.systemPackages;
        pkgs.runCommand "beagley-ai-model-profile" {} ''
          test -f ${model}/share/beagley-ai/models/ONR-CL-6360-regNetx-200mf/artifacts/runtime-contract.json
          mkdir "$out"
        '';
    };
}
