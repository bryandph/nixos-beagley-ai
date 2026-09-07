{
  inputs,
  lib,
  ...
}: {
  perSystem = {system, ...}: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfreePredicate = pkg:
        builtins.elem (lib.getName pkg) [
          "beagley-ai-boot-firmware"
          "beagley-ai-uboot-r5"
          "beagley-ai-uboot-a53"
          "beagley-ai-boot-bundle"
        ];
    };
  };
}
