{
  fetchFromGitHub,
  lib,
  pkgsCross,
}: let
  release = import ./release.nix;
in
  pkgsCross.aarch64-multiplatform.buildOptee {
    pname = "beagley-ai-optee";
    version = release.boot.opteeVersion;
    src = fetchFromGitHub release.sources.optee;
    platform = release.boot.opteePlatform;
    hardeningDisable = ["all"];
    dontStrip = true;
    passthru = {
      provenance = release.sources.optee;
      payload = release.boot.opteePayload;
    };
    extraMeta = {
      description = "OP-TEE secure OS for BeagleY-AI";
      license = lib.licenses.bsd2;
      platforms = lib.platforms.linux;
    };
  }
