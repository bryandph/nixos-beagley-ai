{
  config,
  lib,
  ...
}: let
  profiles = {
    gpio14-15 = ["gpio:main1:14" "gpio:main1:13"];
    uart1 = ["gpio:main1:14" "gpio:main1:13" "uart:main1"];
    i2c-400khz = ["i2c:mcu0:timing"];
    spi0 = ["gpio:mcu0:0" "gpio:mcu0:2" "gpio:mcu0:3" "gpio:mcu0:4" "spi:mcu0"];
    pwm14 = ["gpio:main1:14" "pwm:epwm0"];
    pwm12 = ["gpio:main1:16" "pwm:ecap0"];
    mcasp0 = ["gpio:main1:9" "gpio:main1:10" "gpio:main1:11" "gpio:main1:12" "mcasp:0"];
  };
in {
  flake.modules.nixos = lib.mapAttrs' (name: resources:
    lib.nameValuePair "beagley-ai-header-${name}" ({pkgs, ...}: {
      imports = [config.flake.modules.nixos.beagley-ai-resources];
      hardware.beagleyAi.resourceClaims = lib.genAttrs resources (_: ["header-${name}"]);
      hardware.deviceTree.overlays = [
        {
          name = "beagley-ai-header-${name}";
          filter = "k3-am67a-beagley-ai";
          dtsFile = ../packages + "/expansion-${name}.dtso";
        }
      ];
      environment.systemPackages = [pkgs.libgpiod pkgs.i2c-tools];
    }))
  profiles;
}
