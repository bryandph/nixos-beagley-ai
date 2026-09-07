{lib, ...}: {
  perSystem = {
    config,
    pkgs,
    system,
    ...
  }:
    lib.mkIf (system == "x86_64-linux") {
      packages.beagley-ai-model-tools = pkgs.callPackage ../packages/model-tools.nix {};
      packages.beagley-ai-regnet-model = pkgs.callPackage ../packages/model-regnet.nix {modelTools = config.packages.beagley-ai-model-tools;};
      checks.model-reproducibility = let
        model = config.packages.beagley-ai-regnet-model;
        rebuild = model.overrideAttrs (_: {rebuildMarker = "independent-compilation";});
      in
        pkgs.runCommand "beagley-ai-model-reproducibility" {} ''
          first=${model}/share/beagley-ai/models/ONR-CL-6360-regNetx-200mf
          second=${rebuild}/share/beagley-ai/models/ONR-CL-6360-regNetx-200mf
          diff -r "$first" "$second"
          mkdir "$out"
          cp "$first/artifacts/tidl-compiler-info.json" "$first/artifacts/calibration-manifest.json" "$out/"
        '';
    };
}
