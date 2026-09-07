{lib, ...}: {
  perSystem = {pkgs, ...}:
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      packages.beagley-ai-camera = pkgs.pkgsCross.aarch64-multiplatform.callPackage ../packages/multimedia-camera.nix {};
    };
  flake.modules.nixos.beagley-ai-camera = {pkgs, ...}: {
    environment.systemPackages = [(pkgs.callPackage ../packages/multimedia-camera.nix {})];
  };
}
