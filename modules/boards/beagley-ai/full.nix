{config, ...}: {
  flake.modules.nixos.beagley-ai-full = {
    imports = with config.flake.modules.nixos; [
      beagley-ai-core
      beagley-ai-multimedia
      beagley-ai-gpu
      beagley-ai-wireless
      beagley-ai-vision
      beagley-ai-accelerator-runtime
      beagley-ai-camera
    ];
  };
}
