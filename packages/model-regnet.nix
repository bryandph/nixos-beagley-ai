{
  lib,
  runCommand,
  fetchurl,
  modelTools,
}: let
  release = import ./model-release.nix;
  source = fetchurl (builtins.removeAttrs release.model ["version"]);
in
  runCommand "beagley-ai-regnet-model-${release.version}" {
    nativeBuildInputs = [modelTools];
    meta = {
      description = "RegNet200mf recompiled for J722S TIDL11.02.16 from ONNX with deterministic synthetic calibration";
      license = lib.licenses.unfree;
      platforms = ["x86_64-linux"];
    };
  } ''
      export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
      export SOURCE_DATE_EPOCH=1
      mkdir -p source ONR-CL-6360-regNetx-200mf
      tar -xzf ${source} -C source
    rm -rf source/artifacts
      # Copy only source model inputs. Precompiled vendor artifacts never enter
      # the compiler workspace or output.
      cp -r source/model ONR-CL-6360-regNetx-200mf/model
      chmod -R u+w ONR-CL-6360-regNetx-200mf
      beagley-model-python ${fetchurl release.compilerScript} --model-dir ONR-CL-6360-regNetx-200mf --calibration-frames 12
      beagley-model-python ${./model-calibration.py} ONR-CL-6360-regNetx-200mf/artifacts/calibration-manifest.json
      mkdir -p "$out/share/beagley-ai/models/ONR-CL-6360-regNetx-200mf"
      destination="$out/share/beagley-ai/models/ONR-CL-6360-regNetx-200mf"
      cp -r ONR-CL-6360-regNetx-200mf/model "$destination/model"
      mkdir "$destination/artifacts"
      for file in allowedNode.txt onnxrtMetaData.txt subgraph_0_tidl_io_1.bin subgraph_0_tidl_net.bin tidl-compiler-info.json calibration-manifest.json; do
        cp "ONR-CL-6360-regNetx-200mf/artifacts/$file" "$destination/artifacts/$file"
      done
      beagley-model-python ${./model-runtime-contract.py} "$destination"
      cp source/param.yaml "$destination/param.yaml"
      mkdir -p "$out/share/beagley-ai/model-source-notices"
      find source -type f \( -iname '*license*' -o -iname '*notice*' -o -iname '*copyright*' \) -exec cp --parents '{}' "$out/share/beagley-ai/model-source-notices/" \;
  ''
