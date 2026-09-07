{lib, ...}: {
  perSystem = {pkgs, ...}:
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      packages = {
        beagley-ai-boot-bundle = pkgs.callPackage ../packages/boot-bundle.nix {};
        beagley-ai-boot-firmware = pkgs.callPackage ../packages/boot-firmware.nix {};
        beagley-ai-uboot-r5 = pkgs.callPackage ../packages/uboot.nix {stage = "r5";};
        beagley-ai-uboot-a53 = pkgs.callPackage ../packages/uboot.nix {};
        beagley-ai-arm-trusted-firmware = pkgs.callPackage ../packages/arm-trusted-firmware.nix {};
        beagley-ai-optee = pkgs.callPackage ../packages/optee.nix {};
      };
    };
}
