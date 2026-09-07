{
  stdenv,
  lib,
  callPackage,
  coreutils,
  bash,
}: let
  rpmsg = callPackage ./accelerator-rpmsg.nix {};
in
  stdenv.mkDerivation {
    pname = "beagley-ai-ipc-test";
    inherit (rpmsg) version src;
    patches = [./accelerator-ipc-integrity.patch];
    buildInputs = [rpmsg];
    dontConfigure = true;
    buildPhase = ''
      runHook preBuild
      # Preserve SoC autodetection, with a fallback for board-specific family names.
      substituteInPlace examples/rpmsg_char_simple.c --replace-fail 'rpmsg_char_init(NULL)' 'rpmsg_char_init("J722S")'
      cat > enum-contract.c <<'C'
      #include <rproc_id.h>
      _Static_assert(R5F_MCU0_0 == 0 && R5F_MAIN0_0 == 2 && DSP_C71_0 == 8 && DSP_C71_1 == 10, "TI application core enum changed");
      C
      $CC -c enum-contract.c -o enum-contract.o
      $CC examples/rpmsg_char_simple.c -pthread -lti_rpmsg_char -o rpmsg_char_simple
      runHook postBuild
    '';
    installPhase = ''
      mkdir -p "$out/bin" "$out/libexec"
      install -m555 rpmsg_char_simple "$out/libexec/"
      cat > "$out/bin/beagley-ai-ipc-test" <<EOF
      #!${bash}/bin/bash
      set -euo pipefail
      case "\''${1:-}" in
        mcu-r5) core=0 ;;
        main-r5) core=2 ;;
        c7x0) core=8 ;;
        c7x1) core=10 ;;
        *) echo 'usage: beagley-ai-ipc-test {mcu-r5|main-r5|c7x0|c7x1}' >&2; exit 2 ;;
      esac
      exec ${coreutils}/bin/timeout 20 "$out/libexec/rpmsg_char_simple" -r "\$core" -n 100
      EOF
      chmod +x "$out/bin/beagley-ai-ipc-test"
      install -Dm444 TI_RPMsg_Char_0.1.0_manifest.html "$out/share/licenses/beagley-ai-ipc-test/manifest.html"
    '';
    meta = {
      license = lib.licenses.bsd3;
      platforms = ["aarch64-linux"];
    };
  }
