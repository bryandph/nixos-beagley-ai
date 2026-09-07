{lib, ...}: {
  perSystem = {
    config,
    pkgs,
    system,
    ...
  }:
    lib.mkIf (system == "x86_64-linux") {
      checks.accelerator-firmware-contract = pkgs.callPackage ../packages/accelerator-firmware-check.nix {
        firmware = config.packages.beagley-ai-accelerator-firmware;
      };
      packages =
        {beagley-ai-accelerator-firmware = pkgs.callPackage ../packages/accelerator-firmware.nix {};}
        // lib.genAttrs [
          "beagley-ai-accelerator-armllvm"
          "beagley-ai-accelerator-c7000"
          "beagley-ai-accelerator-sysconfig"
        ] (name:
          pkgs.callPackage ../packages/accelerator-tool.nix {
            tool = lib.removePrefix "beagley-ai-accelerator-" name;
          });
    };
}
