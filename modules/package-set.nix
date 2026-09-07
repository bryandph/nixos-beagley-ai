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
          "beagley-ai-codec-firmware"
          "beagley-ai-rogue-userspace"
          "beagley-ai-wireless-firmware"
          "beagley-ai-accelerator-armllvm"
          "beagley-ai-accelerator-c7000"
          "beagley-ai-accelerator-sysconfig"
          "beagley-ai-accelerator-firmware"
          "beagley-ai-accelerator-runtime"
          "beagley-ai-tidl"
          "beagley-ai-osrt"
          "beagley-ai-ipc-firmware"
          "beagley-ai-edgeai-libraries"
          "beagley-ai-edgeai-gstreamer"
          "beagley-ai-imx219-dcc"
          "beagley-ai-model-tools"
          "beagley-ai-regnet-model"
        ];
    };
  };
}
