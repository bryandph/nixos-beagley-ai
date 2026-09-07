{config, ...}: let
  resources = config.flake.modules.nixos.beagley-ai-resources;
in {
  flake.modules.nixos = {
    beagley-ai-oldi-lcd185 = {
      imports = [resources];
      hardware.beagleyAi.resourceClaims = {
        "connector:oldi" = ["oldi-lcd185"];
        "gpio:mcu0:11" = ["oldi-lcd185"];
        "gpio:main0:14" = ["oldi-lcd185"];
        "pwm:ecap0" = ["oldi-lcd185"];
        "i2c:main1:0x57" = ["oldi-lcd185"];
        "i2c:main1:0x5d" = ["oldi-lcd185"];
        "display:dss0:vp1" = ["oldi-lcd185"];
      };
      hardware.deviceTree.overlays = [
        {
          name = "beagley-ai-oldi-lcd185";
          filter = "k3-am67a-beagley-ai";
          dtsFile = ../../../packages/multimedia-oldi-lcd185.dtso;
        }
      ];
    };
    beagley-ai-csi0-imx219 = {
      imports = [resources];
      hardware.beagleyAi.resourceClaims = {
        "connector:csi0" = ["csi0-imx219"];
        "gpio:mcu0:15" = ["csi0-imx219"];
        "i2c:main2:0x10" = ["csi0-imx219"];
      };
      hardware.deviceTree.overlays = [
        {
          name = "beagley-ai-csi0-imx219";
          filter = "k3-am67a-beagley-ai";
          dtsFile = ../../../packages/multimedia-csi0-imx219.dtso;
        }
      ];
    };
    beagley-ai-csi1-imx219 = {
      imports = [resources];
      hardware.beagleyAi.resourceClaims = {
        "connector:csi1-dsi0" = ["csi1-imx219"];
        "gpio:main0:1" = ["csi1-imx219"];
        "gpio:main0:2" = ["csi1-imx219"];
        "gpio:main1:24" = ["csi1-imx219"];
        "i2c:main0:0x10" = ["csi1-imx219"];
      };
      hardware.deviceTree.overlays = [
        {
          name = "beagley-ai-csi1-imx219";
          filter = "k3-am67a-beagley-ai";
          dtsFile = ../../../packages/multimedia-csi1-imx219.dtso;
        }
      ];
    };
    beagley-ai-dsi-rpi-7inch = {
      imports = [resources];
      hardware.beagleyAi.resourceClaims = {
        "connector:csi1-dsi0" = ["dsi-rpi-7inch"];
        "gpio:main0:1" = ["dsi-rpi-7inch"];
        "gpio:main0:2" = ["dsi-rpi-7inch"];
        "i2c:main0:0x45" = ["dsi-rpi-7inch"];
        "display:dss1:vp2" = ["dsi-rpi-7inch"];
      };
      hardware.deviceTree.overlays = [
        {
          name = "beagley-ai-dsi-rpi-7inch";
          filter = "k3-am67a-beagley-ai";
          dtsFile = ../../../packages/multimedia-dsi-rpi-7inch.dtso;
        }
      ];
    };
  };
}
