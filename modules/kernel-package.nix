{lib, ...}: {
  perSystem = {pkgs, ...}:
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      packages.beagley-ai-kernel = pkgs.pkgsCross.aarch64-multiplatform.callPackage ../packages/linux.nix {};
    };
}
