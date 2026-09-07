{
  pkgs,
  lib,
  stdenv,
  runCommand,
  fetchurl,
  unzip,
  makeWrapper,
  glibc,
  graphviz,
}: let
  release = import ./model-release.nix;
  python = import ./model-python.nix {inherit pkgs;};
  env = python.withPackages (p: [p.numpy p.coloredlogs p.flatbuffers p.packaging p.protobuf p.sympy]);
  libraries = lib.makeLibraryPath [glibc stdenv.cc.cc.lib graphviz];
in
  assert stdenv.hostPlatform.system == "x86_64-linux" && !stdenv.hostPlatform.isStatic;
    runCommand "beagley-ai-model-tools-${release.version}" {
      nativeBuildInputs = [unzip makeWrapper];
      meta = {
        description = "Unmodified TI J722S x86 TIDL compiler with matched CPython3.10 environment";
        license = lib.licenses.unfree;
        platforms = ["x86_64-linux"];
      };
    } ''
      mkdir -p "$out/lib/original" "$out/lib/tidl-tools" "$out/python" "$out/bin"
      tar -xzf ${fetchurl release.tools} -C "$out/lib/original" --strip-components=1
      for file in "$out"/lib/original/*; do
        ln -s "$file" "$out/lib/tidl-tools/$(basename "$file")"
      done
      for program in "$out"/lib/original/*.out; do
        target="$out/lib/tidl-tools/$(basename "$program")"
        rm "$target"
        makeWrapper ${glibc}/lib/ld-linux-x86-64.so.2 "$target" --add-flags "--library-path $out/lib/original:${libraries} $program"
      done
      unzip -q ${fetchurl release.onnx} -d "$out/python"
      unzip -q ${fetchurl release.tflite} -d "$out/python"
      makeWrapper ${env}/bin/python "$out/bin/beagley-model-python" \
        --prefix PYTHONPATH : "$out/python" \
        --prefix LD_LIBRARY_PATH : "$out/lib/tidl-tools:${libraries}" \
        --set GLIBC_TUNABLES glibc.rtld.execstack=2 \
        --set TIDL_TOOLS_PATH "$out/lib/tidl-tools" --set SOC J722S \
        --set TI_TIDL_TOOLS_VERSION ${release.version} \
        --set EDGEAI_TIDL_MODELS_SDK_VERSION ${release.model.version} \
        --set TI_TIDL_TOOLS_J722S_ARCHIVE_SHA256 ${release.tools.hash} \
        --set TI_TIDL_TOOLS_X86_ONNX_WHEEL_SHA256 ${release.onnx.hash}
      "$out/bin/beagley-model-python" -c 'import sys, numpy, onnxruntime as ort; from tflite_runtime.interpreter import Interpreter; assert sys.version_info[:2] == (3,10); assert numpy.__version__ == "1.26.4"; assert "TIDLCompilationProvider" in ort.get_available_providers()'
    ''
