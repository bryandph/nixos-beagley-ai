{config, ...}: {
  flake.nixosModules = {
    inherit (config.flake.modules.nixos) beagley-ai-full;
    inherit (config.flake.modules.nixos) beagley-ai-regnet-model;
    inherit (config.flake.modules.nixos) beagley-ai-usb-gadget beagley-ai-header-gpio14-15 beagley-ai-header-uart1 beagley-ai-header-i2c-400khz beagley-ai-header-spi0 beagley-ai-header-pwm14 beagley-ai-header-pwm12 beagley-ai-header-mcasp0;
    inherit (config.flake.modules.nixos) beagley-ai-accelerator-runtime beagley-ai-remoteproc-ipc beagley-ai-vision beagley-ai-camera;
    inherit (config.flake.modules.nixos) beagley-ai-oldi-lcd185;
    inherit (config.flake.modules.nixos) beagley-ai-csi0-imx219 beagley-ai-csi1-imx219 beagley-ai-dsi-rpi-7inch;
    inherit (config.flake.modules.nixos) beagley-ai-core beagley-ai-sd-image beagley-ai-multimedia beagley-ai-gpu beagley-ai-wireless;
  };
}
