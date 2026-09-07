{
  callPackage,
  lib,
  runCommand,
}: let
  release = import ./release.nix;
  r5 = callPackage ./uboot.nix {stage = "r5";};
  a53 = callPackage ./uboot.nix {};
  firmware = callPackage ./boot-firmware.nix {};
in
  runCommand "beagley-ai-boot-bundle-${release.boot.ubootVersion}" {
    passthru = {
      inherit (release) provider;
      inherit (release.firmware) publicationPolicy;
      components = {inherit r5 a53 firmware;};
    };
    meta.license = [lib.licenses.gpl2Plus lib.licenses.unfreeRedistributable];
  } ''
    mkdir -p "$out/share"
    cp ${r5}/tiboot3.bin ${a53}/tispl.bin ${a53}/u-boot.img "$out/"
    cp -r ${firmware}/share/licenses "$out/share/"
    cd "$out"
    sha256sum tiboot3.bin tispl.bin u-boot.img > SHA256SUMS
  ''
