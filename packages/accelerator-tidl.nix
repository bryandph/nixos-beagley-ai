{
  lib,
  stdenv,
  fetchgit,
  callPackage,
  pkg-config,
  libglvnd,
  libdrm,
  protobuf,
  python3,
}: let
  release = import ./accelerator-release.nix;
  pins = builtins.fromJSON (builtins.readFile ./accelerator-tidl-sources.json);
  source = pin:
    fetchgit {
      name = "source";
      inherit (pin) url rev hash;
    };
  sources = builtins.listToAttrs (map (pin: {
      name = pin.name;
      value = source pin;
    })
    pins);
  runtime = callPackage ./accelerator-runtime.nix {};
  projects = builtins.listToAttrs (map (pin: {
      name = pin.path;
      value = source pin;
    })
    runtime.manifest);
  mesa = callPackage ./multimedia-mesa.nix {};
in
  stdenv.mkDerivation {
    pname = "beagley-ai-tidl";
    inherit (release.sdk) version;
    src = sources.arm-tidl;
    outputs = ["out" "dev"];
    nativeBuildInputs = [pkg-config python3];
    buildInputs = [runtime runtime.rpmsg libglvnd mesa libdrm protobuf];
    dontConfigure = true;
    enableParallelBuilding = true;
    buildPhase = ''
      runHook preBuild
      export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE -I$PWD/tiovx_kernels/include"
      export NIX_LDFLAGS="$NIX_LDFLAGS -L${runtime}/lib"
      make -j"$NIX_BUILD_CORES" GCC_LINUX_ARM_ROOT=${stdenv.cc} CROSS_COMPILE_LINARO=${stdenv.cc.targetPrefix} \
        TARGET_SOC=J722S PSDK_INSTALL_PATH="$PWD" CONCERTO_ROOT=${sources.concerto} \
        TF_REPO_PATH=${sources.tensorflow} ONNX_REPO_PATH=${sources.onnxruntime} TIDL_PROTOBUF_PATH=${sources.protobuf} \
        TIDL_PATH=${projects.psdk_include}/tidl_j7 IVISION_PATH=${projects.psdk_include}/ivision \
        TIOVX_PATH=${projects.tiovx} VISION_APPS_PATH=${projects.vision_apps} APP_UTILS_PATH=${projects.app_utils} \
        LINUX_SYSROOT_ARM= LINUX_FS_PATH=/nonexistent TREAT_WARNINGS_AS_ERROR=0
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib" "$dev/include" "$out/share/beagley-ai" "$out/share/licenses/beagley-ai-tidl"
      for component in rt tfl_delegate onnxrt_ep tidlrt_ep; do
        find "$component/out/J722S/A53/LINUX/release" -maxdepth 1 \( -name '*.so' -o -name '*.so.[0-9]*' \) -exec cp -P {} "$out/lib/" \;
        if test -d "$component/inc"; then
          mkdir -p "$dev/include/$component"
          cp -r "$component/inc/." "$dev/include/$component/"
        fi
      done
      cp ${./accelerator-tidl-sources.json} "$out/share/beagley-ai/tidl-sources.json"
      cp -r ${runtime}/share/licenses/beagley-ai-accelerator-runtime "$out/share/licenses/beagley-ai-tidl/sdk"
      for component in ${sources.tensorflow} ${sources.onnxruntime} ${sources.protobuf}; do
        for notice in "$component"/LICENSE* "$component"/NOTICE*; do
          if test -f "$notice"; then
            install -Dm444 "$notice" "$out/share/licenses/beagley-ai-tidl/$(basename "$component")/$(basename "$notice")"
          fi
        done
      done
      find . -type f \( -iname 'license*' -o -iname 'licence*' -o -iname '*manifest*.html' \) -print0 |
        while IFS= read -r -d "" notice; do
          install -Dm444 "$notice" "$out/share/licenses/beagley-ai-tidl/arm-tidl/$notice"
        done
      python3 ${./accelerator-tidl-install.py} "$out" "$dev"
      test -s "$out/lib/libvx_tidl_rt.so"
      test -s "$out/lib/libtidl_tfl_delegate.so"
      test -s "$out/lib/libtidl_onnxrt_EP.so"
      test -s "$out/lib/libtidlrt_EP.so"
      runHook postInstall
    '';
    passthru = {
      inherit runtime pins;
      firmwareVersion = release.sdk.version;
    };
    meta = {
      description = "TI J722S TIDL runtime, TensorFlow Lite delegate and ONNX execution provider";
      license = lib.licenses.unfreeRedistributable;
      platforms = ["aarch64-linux"];
    };
  }
