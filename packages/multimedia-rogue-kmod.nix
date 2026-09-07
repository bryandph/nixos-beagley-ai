{
  lib,
  stdenv,
  fetchurl,
  kernel,
  which,
  python3,
}: let
  release = (import ./multimedia-release.nix).rogue;
in
  stdenv.mkDerivation {
    pname = "beagley-ai-rogue-kmod";
    inherit (release) version;
    src = fetchurl {
      url = "https://codeload.github.com/TexasInstruments/ti-img-rogue-driver/tar.gz/${release.kmd.rev}";
      name = "ti-img-rogue-driver-${release.kmd.rev}.tar.gz";
      inherit (release.kmd) sha256;
    };
    nativeBuildInputs = kernel.moduleBuildDependencies ++ [which python3];
    hardeningDisable = ["pic"];
    enableParallelBuilding = true;
    makeFlags = [
      "-C"
      "build/linux/${release.buildDirectory}"
      "BUILD=release"
      "WINDOW_SYSTEM=lws-generic"
      "KERNELDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      "CROSS_COMPILE=${stdenv.cc.targetPrefix}"
    ];
    installPhase = ''
      runHook preInstall
      find binary_* -name pvrsrvkm.ko -exec install -Dm444 {} "$out/lib/modules/${kernel.modDirVersion}/extra/pvrsrvkm.ko" \;
      test -s "$out/lib/modules/${kernel.modDirVersion}/extra/pvrsrvkm.ko"
      install -Dm444 MIT-COPYING "$out/share/licenses/beagley-ai-rogue-kmod/MIT-COPYING"
      install -Dm444 GPL-COPYING "$out/share/licenses/beagley-ai-rogue-kmod/GPL-COPYING"
      runHook postInstall
    '';
    passthru = {
      inherit kernel;
      provenance = release;
    };
    meta = {
      description = "TI J722S Rogue kernel driver matching the 25.2 userspace ABI";
      license = with lib.licenses; [mit gpl2Only];
      platforms = ["aarch64-linux"];
    };
  }
