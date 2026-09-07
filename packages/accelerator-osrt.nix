{
  lib,
  stdenv,
  runCommand,
  fetchurl,
  callPackage,
  python312,
  unzip,
  makeWrapper,
}: let
  pins = builtins.fromJSON (builtins.readFile ./accelerator-osrt-wheels.json);
  wheels = map (pin:
    fetchurl {
      name = pin.file;
      inherit (pin) url hash;
    })
  pins;
  python = python312.override {
    packageOverrides = _: prev: {
      numpy = prev.numpy_1;
      # Keep the vendor wheel's NumPy 1 ABI. ml-dtypes supports NumPy 1 at
      # runtime; its upstream build pin otherwise forces a second NumPy ABI.
      ml-dtypes = prev.ml-dtypes.overridePythonAttrs (old: {
        postPatch =
          old.postPatch
          + ''
            substituteInPlace pyproject.toml --replace-fail 'numpy~=2.0' 'numpy>=1.26.4'
          '';
      });
    };
  };
  environment = python.withPackages (p: with p; [numpy coloredlogs flatbuffers packaging protobuf sympy attrs cloudpickle decorator graphviz ml-dtypes psutil scipy tornado typing-extensions]);
  tidl = callPackage ./accelerator-tidl.nix {};
  runtime = tidl.runtime;
  mesa = callPackage ./multimedia-mesa.nix {};
in
  runCommand "beagley-ai-osrt-11.02.16.00" {
    nativeBuildInputs = [unzip makeWrapper python];
    passthru = {inherit pins python tidl;};
    meta = {
      description = "Unmodified TI aarch64 CPython 3.12 OSRT wheels with matched TIDL runtime";
      license = lib.licenses.unfreeRedistributable;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      platforms = ["aarch64-linux"];
    };
  } ''
    mkdir -p "$out/libexec" "$out/python" "$out/bin" "$out/share/beagley-ai" "$out/share/licenses/beagley-ai-osrt"
    ${lib.concatMapStringsSep "\n" (wheel: ''unzip -q ${wheel} -d "$out/python"'') wheels}
    python ${./accelerator-osrt-integrity.py} "$out/python" ${lib.concatStringsSep " " (map toString wheels)}
    cp ${./accelerator-osrt-wheels.json} "$out/share/beagley-ai/osrt-wheels.json"
    cp -r ${runtime}/share/licenses/beagley-ai-accelerator-runtime "$out/share/licenses/beagley-ai-osrt/sdk"
    cp -r ${tidl}/share/licenses/beagley-ai-tidl "$out/share/licenses/beagley-ai-osrt/tidl"
    cp ${./beagley_model_contract.py} "$out/libexec/beagley_model_contract.py"
    PYTHONPATH="$out/libexec" PYTHONDONTWRITEBYTECODE=1 python ${./model-runtime-contract-check.py} ${./model-runtime-contract.py}
    makeWrapper ${environment}/bin/python "$out/bin/beagley-ai-osrt-python" \
      --prefix PYTHONPATH : "$out/python:$out/libexec" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [tidl runtime runtime.rpmsg mesa stdenv.cc.cc.lib]}" \
      --set PYTHONDONTWRITEBYTECODE 1
    makeWrapper "$out/bin/beagley-ai-osrt-python" "$out/bin/beagley-ai-tidl-check" \
      --add-flags ${./accelerator-tidl-check.py}
    makeWrapper "$out/bin/beagley-ai-osrt-python" "$out/bin/beagley-ai-osrt-check" \
      --add-flags ${./accelerator-osrt-check.py}
  ''
