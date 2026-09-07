{
  config,
  lib,
  ...
}: let
  board = config.flake.nixosConfigurations.beagley-ai.config;
  failed = builtins.filter (a: !a.assertion) board.assertions;
in {
  perSystem = {pkgs, ...}: {
    checks =
      {
        sd-identity-guard = pkgs.callPackage ../packages/sd-identity-check.nix {};
        core-composition = assert failed == [];
        assert builtins.attrNames board.fileSystems == ["/" "/boot"];
        assert !board.services.openssh.enable;
        assert board.boot.loader.generic-extlinux-compatible.configurationLimit >= 2;
          pkgs.runCommand "beagley-ai-core-composition" {} ''
            mkdir "$out"
            cat > "$out/composition.json" <<'EOF'
            ${builtins.toJSON {
              dtb = board.hardware.deviceTree.name;
              kernel = board.boot.kernelPackages.kernel.version;
              filesystems = builtins.attrNames board.fileSystems;
              console = board.boot.kernelParams;
            }}
            EOF
          '';
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        device-tree-contract = pkgs.callPackage ../packages/device-tree-check.nix {
          deviceTree = board.hardware.deviceTree.package;
        };
        boot-reproducibility = let
          r5 = pkgs.callPackage ../packages/uboot.nix {stage = "r5";};
          a53 = pkgs.callPackage ../packages/uboot.nix {};
          r5Again = r5.overrideAttrs {BEAGLEY_REPRO_INSTANCE = "second";};
          a53Again = a53.overrideAttrs {BEAGLEY_REPRO_INSTANCE = "second";};
        in
          pkgs.runCommand "beagley-ai-boot-reproducibility" {} ''
            cmp ${r5}/tiboot3.bin ${r5Again}/tiboot3.bin
            cmp ${a53}/tispl.bin ${a53Again}/tispl.bin
            cmp ${a53}/u-boot.img ${a53Again}/u-boot.img
            mkdir "$out"
            sha256sum ${r5}/tiboot3.bin ${a53}/tispl.bin ${a53}/u-boot.img > "$out/SHA256SUMS"
          '';
        boot-structure = (
          let
            bundle = config.flake.packages.${pkgs.stdenv.hostPlatform.system}.beagley-ai-boot-bundle;
          in
            pkgs.runCommand "beagley-ai-boot-structure" {nativeBuildInputs = [pkgs.dtc pkgs.openssl (pkgs.python3.withPackages (p: [p.cryptography]))];} ''
              cd ${bundle}
              sha256sum -c SHA256SUMS
              openssl x509 -inform DER -in tiboot3.bin -noout -subject
              test "$(fdtget -t s tispl.bin /configurations/conf-0 firmware)" = atf
              test "$(fdtget -t s tispl.bin /configurations/conf-0 loadables)" = 'tee dm spl'
              fdtget -t s u-boot.img /configurations/conf-0 firmware
              python3 ${../packages/boot-artifact-check.py} ${bundle} ${bundle.components.r5}/.config ${bundle.components.a53}/.config
              mkdir "$out"
              cp SHA256SUMS "$out/"
            ''
        );
      };
  };
}
