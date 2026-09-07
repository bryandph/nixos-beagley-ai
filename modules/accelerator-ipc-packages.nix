{lib, ...}: {
  perSystem = {pkgs, ...}:
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      checks.accelerator-lifecycle = pkgs.runCommand "beagley-ai-accelerator-lifecycle-guards" {nativeBuildInputs = [pkgs.python3];} ''
        python3 ${../packages/accelerator-remoteproc-test.py} ${../packages/accelerator-remoteproc.py}
        touch "$out"
      '';
      packages.beagley-ai-ipc-firmware = pkgs.callPackage ../packages/accelerator-ipc-firmware.nix {};
      packages.beagley-ai-ipc-test = pkgs.pkgsCross.aarch64-multiplatform.callPackage ../packages/accelerator-ipc-test.nix {};
    };
}
