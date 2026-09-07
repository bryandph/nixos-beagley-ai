{...}: {
  flake.modules.nixos.beagley-ai-resources = {
    config,
    lib,
    ...
  }: {
    key = "beagley-ai-resources";
    options.hardware.beagleyAi.resourceClaims = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = {};
      description = "Exclusive board connector, pin or controller ownership by composed profiles.";
    };
    config.assertions =
      lib.mapAttrsToList (resource: owners: {
        assertion = builtins.length (lib.unique owners) <= 1;
        message = "BeagleY-AI resource ${resource} has incompatible owners: ${lib.concatStringsSep ", " (lib.unique owners)}";
      })
      config.hardware.beagleyAi.resourceClaims;
  };
}
