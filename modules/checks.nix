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
        boot-structure = (
          let
            bundle = config.flake.packages.${pkgs.stdenv.hostPlatform.system}.beagley-ai-boot-bundle;
          in
            pkgs.runCommand "beagley-ai-boot-structure" {nativeBuildInputs = [pkgs.dtc pkgs.openssl];} ''
              cd ${bundle}
              sha256sum -c SHA256SUMS
              openssl x509 -inform DER -in tiboot3.bin -noout -subject
              test "$(fdtget -t s tispl.bin /configurations/conf-0 firmware)" = atf
              test "$(fdtget -t s tispl.bin /configurations/conf-0 loadables)" = 'tee dm spl'
              fdtget -t s u-boot.img /configurations/conf-0 firmware
              mkdir "$out"
              cp SHA256SUMS "$out/"
            ''
        );
      };
  };
}
