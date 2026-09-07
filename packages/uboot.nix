{
  fetchFromGitHub,
  lib,
  pkgsCross,
  python3,
  callPackage,
  stage ? "a53",
}: let
  release = import ./release.nix;
  r5 = stage == "r5";
  cross =
    if r5
    then pkgsCross.arm-embedded
    else pkgsCross.aarch64-multiplatform;
  firmware = callPackage ./boot-firmware.nix {};
  tfA = callPackage ./arm-trusted-firmware.nix {};
  optee = callPackage ./optee.nix {};
  python = python3.withPackages (p: [p.libfdt p.setuptools p.pyelftools p.pyyaml p.yamllint p.jsonschema p.cryptography]);
in
  assert builtins.elem stage ["r5" "a53"];
    (cross.buildUBoot {
      pname = "beagley-ai-uboot-${stage}";
      version = release.boot.ubootVersion;
      src = fetchFromGitHub release.sources.uboot;
      defconfig =
        if r5
        then release.boot.r5Defconfig
        else release.boot.a53Defconfig;
      filesToInstall =
        if r5
        then ["tiboot3.bin" "spl/u-boot-spl.bin" ".config"]
        else ["tispl.bin" "u-boot.img" ".config"];
      extraMakeFlags =
        ["BINMAN_INDIRS=${firmware}"]
        ++ lib.optionals (!r5) [
          "BL31=${tfA}/bl31.bin"
          "TEE=${optee}/${release.boot.opteePayload}"
        ];
      extraMeta = {
        description = "BeagleY-AI ${stage} U-Boot stage";
        platforms =
          if r5
          then ["arm-none"]
          else lib.platforms.linux;
        license = [lib.licenses.gpl2Plus lib.licenses.unfreeRedistributable];
      };
      passthru = {
        provenance = release.sources.uboot;
        inherit firmware;
      };
    }).overrideAttrs (old: {
      postPatch =
        old.postPatch
        + ''
            # Fail on missing payloads; never permit binman's test placeholders.
            substituteInPlace Makefile --replace-fail "--allow-missing --fake-ext-blobs" ""
          # HS-FS uses upstream's public test key. Pin certificate metadata rather
          # than taking OpenSSL's wall clock and random serial defaults.
          # OpenSSL >= 3.4 supports explicit req validity dates.
          substituteInPlace tools/binman/btool/openssl.py \
            --replace-fail "'req', '-new', '-x509', '-key'" \
            "'req', '-new', '-x509', '-set_serial', '1', '-not_before', '20200101000000Z', '-not_after', '20400101000000Z', '-key'"
        ''
        + lib.optionalString r5 ''
          # Build the selected HS-FS variant; HS-SE requires different firmware.
          cat >> arch/arm/dts/k3-am67a-beagley-ai-u-boot.dtsi <<'EOF'
          #if IS_ENABLED(CONFIG_TARGET_J722S_R5_BEAGLEY_AI)
          &binman {
            /delete-node/ tiboot3-j722s-hs-evm.bin;
          };
          #endif
          EOF
        '';
      nativeBuildInputs = builtins.filter (p: p != null && !(lib.hasPrefix "python3" (lib.getName p))) old.nativeBuildInputs ++ [python];
    })
