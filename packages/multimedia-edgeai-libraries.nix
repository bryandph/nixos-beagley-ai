{
  lib,
  stdenv,
  fetchgit,
  callPackage,
  cmake,
  ninja,
  pkg-config,
  python3,
}: let
  sources = builtins.fromJSON (builtins.readFile ./multimedia-edgeai-sources.json);
  runtime = callPackage ./accelerator-runtime.nix {};
  imagingPin = builtins.head (builtins.filter (project: project.path == "imaging") runtime.manifest);
  imaging = fetchgit {inherit (imagingPin) url rev hash;};
  twoAIncludes = ["algos/awb/include" "algos/ae/include" "kernels/include" "ti_2a_wrapper/include" "kernels/aewb/arm" "algos/dcc/include" "sensor_drv/include" "itt_server_remote/include"];
  projects = ["utils" "kernels" "modules"];
  source = name: fetchgit (sources.${name} // {name = "source";});
in
  stdenv.mkDerivation {
    pname = "beagley-ai-edgeai-libraries";
    version = "11.02.01.03";
    dontUnpack = true;
    dontConfigure = true;
    nativeBuildInputs = [cmake ninja pkg-config python3];
    buildInputs = [runtime runtime.rpmsg];
    SOC = "j722s";
    buildPhase = ''
      runHook preBuild
      mkdir -p sdk/include/processor_sdk "$out/include" "$out/lib"
      cp -rs ${runtime.dev}/include/ti-edgeai/* sdk/include/processor_sdk/
      ln -s ${runtime.dev}/include/ti-edgeai/psdk_include/vxlib sdk/include/processor_sdk/vxlib
      ln -s ${runtime.dev}/include/ti-edgeai/psdk_include/ivision sdk/include/processor_sdk/ivision
      ln -s ${runtime.dev}/include/ti-edgeai/psdk_include/tidl_j7 sdk/include/processor_sdk/tidl_j7
      export PSDK_INCLUDE_PATH="$PWD/sdk/include"
      export NIX_LDFLAGS="$NIX_LDFLAGS -L$out/lib -rpath $out/lib"
      ${lib.concatMapStringsSep "\n" (name: ''
          cp -r ${source name} ${name}
          chmod -R u+w ${name}
          if [ "${name}" = modules ]; then
            substituteInPlace modules/CMakeLists.txt modules/cmake/common.cmake \
              --replace-fail 'STREQUAL "AM62A")' 'STREQUAL "AM62A" OR "''${TARGET_SOC}" STREQUAL "J722S")'
          fi
          # Installed headers live in the SDK sysroot; preserve upstream includes.
          cmake -S ${name} -B build-${name} -G Ninja \
            -DCMAKE_INSTALL_PREFIX="$out" -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
            -DCMAKE_BUILD_TYPE=Release -DCMAKE_BUILD_RPATH="$out/lib;${runtime}/lib"
          cmake --build build-${name} --parallel "$NIX_BUILD_CORES"
          cmake --install build-${name}
          cp -rsn "$out/include/"* sdk/include/
          mkdir -p "$out/share/licenses/edgeai-${name}"
          cp ${name}/LICENSE "$out/share/licenses/edgeai-${name}/"
        '')
        projects}
      # TI's J722S aggregate omits the host 2A wrapper, while exporting its AE/AWB
      # algorithms. Build the matched wrapper source against that exact runtime.
      $CC -shared -fPIC -DSOC_J722S -DTARGET_CPU_A53 -DTARGET_OS_LINUX \
        ${lib.concatMapStringsSep " " (path: "-I${imaging}/${path}") twoAIncludes} \
        -I${runtime.dev}/include/ti-edgeai/tiovx/include \
        -I${runtime.dev}/include/ti-edgeai/tiovx/kernels/include \
        -I${runtime.dev}/include/ti-edgeai/psdk_include/vxlib/packages \
        -I${runtime.dev}/include/ti-edgeai/app_utils/utils/remote_service/include \
        -I${runtime.dev}/include/ti-edgeai/app_utils/utils/ipc/include \
        ${imaging}/ti_2a_wrapper/src/*.c -L${runtime}/lib -ltivision_apps -lm \
        -Wl,--no-undefined -o "$out/lib/libti_2a_wrapper.so"
      mkdir -p "$out/share/licenses/ti-2a-wrapper"
      cp ${imaging}/docs/manifest/Imaging_manifest.html "$out/share/licenses/ti-2a-wrapper/"
      cp ${imaging}/ti_2a_wrapper/src/*.c "$out/share/licenses/ti-2a-wrapper/"
      runHook postBuild
    '';
    installPhase = ''
      mkdir -p "$out/share/beagley-ai"
      cp ${./multimedia-edgeai-sources.json} "$out/share/beagley-ai/edgeai-sources.json"
    '';
    passthru = {inherit runtime sources;};
    meta = {
      description = "Matched TI EdgeAI modules, kernels and J722S host 2A wrapper";
      license = lib.licenses.unfreeRedistributable;
      platforms = ["aarch64-linux"];
    };
  }
