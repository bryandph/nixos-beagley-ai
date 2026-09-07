{
  fetchFromGitHub,
  lib,
  pkgsCross,
}: let
  release = import ./release.nix;
in
  pkgsCross.aarch64-multiplatform.buildArmTrustedFirmware {
    pname = "beagley-ai-arm-trusted-firmware";
    version = release.boot.tfAVersion;
    src = fetchFromGitHub release.sources.tfA;
    platform = release.boot.tfAPlatform;
    extraMakeFlags = ["TARGET_BOARD=${release.boot.tfABoard}" "SPD=opteed"];
    filesToInstall = ["build/k3/lite/release/bl31.bin"];
    patches = [];
    postPatch = "";
    enableParallelBuilding = true;
    passthru.provenance = release.sources.tfA;
    extraMeta = {
      description = "TI Trusted Firmware-A BL31 for BeagleY-AI";
      license = lib.licenses.bsd3;
      platforms = lib.platforms.linux;
    };
  }
