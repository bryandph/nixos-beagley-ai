{lib, ...}: {
  perSystem = {pkgs, ...}:
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      packages.beagley-ai-accelerator-runtime = pkgs.pkgsCross.aarch64-multiplatform.callPackage ../packages/accelerator-runtime.nix {};
      packages.beagley-ai-ti-rpmsg-char = pkgs.pkgsCross.aarch64-multiplatform.callPackage ../packages/accelerator-rpmsg.nix {};
      packages.beagley-ai-tidl = pkgs.pkgsCross.aarch64-multiplatform.callPackage ../packages/accelerator-tidl.nix {};
      packages.beagley-ai-edgeai-gstreamer = pkgs.pkgsCross.aarch64-multiplatform.callPackage ../packages/multimedia-edgeai-gstreamer.nix {};
      packages.beagley-ai-imx219-dcc = pkgs.pkgsCross.aarch64-multiplatform.callPackage ../packages/multimedia-imx219-dcc.nix {};
      packages.beagley-ai-edgeai-libraries = pkgs.pkgsCross.aarch64-multiplatform.callPackage ../packages/multimedia-edgeai-libraries.nix {};
      packages.beagley-ai-osrt = pkgs.pkgsCross.aarch64-multiplatform.callPackage ../packages/accelerator-osrt.nix {};
    };
  flake.modules.nixos.beagley-ai-accelerator-runtime = {pkgs, ...}: {
    environment.systemPackages = [(pkgs.callPackage ../packages/accelerator-runtime.nix {}) (pkgs.callPackage ../packages/accelerator-tidl.nix {}) (pkgs.callPackage ../packages/accelerator-osrt.nix {})];
  };
}
