{
  config,
  lib,
  ...
}: {
  perSystem = {pkgs, ...}:
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      checks.accelerator-memory-map = let
        runtime = config.flake.packages.aarch64-linux.beagley-ai-accelerator-runtime;
        firmware = config.flake.packages.x86_64-linux.beagley-ai-accelerator-firmware;
      in
        pkgs.runCommand "beagley-ai-accelerator-memory-map" {} ''
          cmp ${runtime}/share/beagley-ai/app_mem_map.h ${firmware}/share/beagley-ai/app_mem_map.h
          cmp ${runtime}/share/beagley-ai/k3-j722s-rtos-memory-map.dtsi ${firmware}/share/beagley-ai/k3-j722s-rtos-memory-map.dtsi
          mkdir "$out"
          cp ${runtime}/share/beagley-ai/app_mem_map.h "$out/"
          sha256sum "$out/app_mem_map.h" > "$out/SHA256SUMS"
        '';
    };
}
