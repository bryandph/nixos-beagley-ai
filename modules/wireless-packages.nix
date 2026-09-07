{lib, ...}: {
  perSystem = {pkgs, ...}:
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      packages.beagley-ai-wireless-firmware = pkgs.callPackage ../packages/wireless-firmware.nix {};
      checks.wireless-firmware = pkgs.callPackage ../packages/wireless-firmware.nix {};
    };
}
