{config, ...}: {
  flake.modules.nixos.beagley-ai-regnet-model = {
    environment.systemPackages = [config.flake.packages.x86_64-linux.beagley-ai-regnet-model];
    environment.pathsToLink = ["/share/beagley-ai/models"];
  };
}
