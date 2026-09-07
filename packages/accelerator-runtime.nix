{
  lib,
  buildPackages,
  stdenv,
  fetchgit,
  fetchurl,
  callPackage,
  runCommand,
  python3,
  pkg-config,
  glm,
  freetype,
  libdrm,
  libglvnd,
  pam,
  zlib,
  libpng,
  nlohmann_json,
  stb,
}: let
  release = import ./accelerator-release.nix;
  manifest = builtins.fromJSON (builtins.readFile ./accelerator-runtime-sources.json);
  source = project: fetchgit {inherit (project) url rev hash;};
  rpmsg = callPackage ./accelerator-rpmsg.nix {};
  mesa = callPackage ./multimedia-mesa.nix {};
  sdk = fetchurl {inherit (release.sdk) url hash;};
  sdkLicense = runCommand "beagley-ai-sdk-license-${release.sdk.version}" {} ''
    mkdir -p "$out"
    tar -xOf ${sdk} ti-processor-sdk-rtos-j722s-evm-11_02_01_03/psdk_rtos/PROCESSOR_SDK_RTOS_J722S_manifest.html > "$out/PROCESSOR_SDK_RTOS_J722S_manifest.html"
  '';
  patchFile = name:
    fetchurl {
      url = "https://raw.githubusercontent.com/TexasInstruments-Sandbox/ti-edgeai-armbian-build/${release.reference.revision}/patches/firmware/${name}";
      sha256 = release.reference.patches.${name};
    };
in
  stdenv.mkDerivation {
    pname = "beagley-ai-accelerator-runtime";
    inherit (release.sdk) version;
    outputs = ["out" "dev"];
    dontUnpack = true;
    dontConfigure = true;
    nativeBuildInputs = [pkg-config python3];
    buildInputs = [rpmsg glm freetype libdrm libglvnd mesa pam zlib libpng nlohmann_json stb];
    enableParallelBuilding = true;
    buildPhase = ''
      runHook preBuild
      mkdir workspace
      cd workspace
      ${lib.concatMapStringsSep "\n" (project: ''
          mkdir -p ${project.path}
          cp -r ${source project}/. ${project.path}/
        '')
        manifest}
      chmod -R u+w .
      patch -p1 < ${./accelerator-ipc-init-failure.patch}
      BUILD_CC=${buildPackages.stdenv.cc}/bin/cc python3 ${./accelerator-ipc-init-regression.py}
      export PSDK_PATH="$PWD"
      patch -d vision_apps -p1 < ${patchFile "j722s-4gb-edgeai-memory-map.patch"}
      patch -d vision_apps -p1 < ${patchFile "j722s-edgeai-disable-cpsw.patch"}
      (
        cd vision_apps/platform/j722s/rtos
        PYTHONPATH="$PSDK_PATH/vision_apps/tools/PyTI_PSDK_RTOS" python3 gen_linker_mem_map.py
        grep -q 'DDR_SHARED_MEM_PHYS_ADDR (0x8A0000000u)' app_mem_map.h
      )
      export SOC=j722s TISDK_IMAGE=edgeai PROFILE=release BUILD_ENABLE_ETHFW=no
      export CROSS_COMPILE_LINARO=${stdenv.cc.targetPrefix}
      export GCC_LINUX_ARM_ROOT=${stdenv.cc} GCC_LINUX_ARM_ROOT_A72=${stdenv.cc}
      export LINUX_SYSROOT_ARM= LINUX_FS_PATH=/nonexistent TREAT_WARNINGS_AS_ERROR=0
      export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE $(pkg-config --cflags libdrm freetype2) -I${stb}/include/stb"
      # The EdgeAI profile does not define these ADAS-only FD exchange targets.
      substituteInPlace sdk_builder/makerules/makefile_linux_arm.mak \
        --replace-fail "vx_app_arm_fd_exchange_consumer vx_app_arm_fd_exchange_producer" ""
      make -C sdk_builder -j"$NIX_BUILD_CORES" yocto_build
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      result=vision_apps/out/J722S/A53/LINUX/release
      mkdir -p "$out/lib" "$out/bin" "$out/share/beagley-ai" "$dev/include/ti-edgeai" "$dev/lib/pkgconfig"
      find "$result" -maxdepth 1 \( -name '*.so' -o -name '*.so.[0-9]*' \) -exec cp -P {} "$out/lib/" \;
      cp "$result"/*.a "$dev/lib/"
      for executable in "$result"/*.out; do
        install -m755 "$executable" "$out/bin/$(basename "$executable" .out)"
      done
      install -m444 vision_apps/platform/j722s/rtos/{app_mem_map.h,k3-j722s-rtos-memory-map.dtsi} "$out/share/beagley-ai/"
      cp ${./accelerator-runtime-sources.json} "$out/share/beagley-ai/runtime-sources.json"
      mkdir -p "$out/share/licenses/beagley-ai-accelerator-runtime"
      cp ${sdkLicense}/* "$out/share/licenses/beagley-ai-accelerator-runtime/"
      # Retain component-specific copyright and license text, including notices
      # carried in source headers rather than standalone LICENSE files.
      python3 ${./accelerator-runtime-install.py} "$out" "$dev"
      ln -s ti-edgeai/tiovx/include/VX "$dev/include/VX"
      ln -s ti-edgeai/tiovx/include/TI "$dev/include/TI"
      cat > "$dev/lib/pkgconfig/tivision_apps.pc" <<EOF
      prefix=$out
      libdir=$out/lib
      includedir=$dev/include
      Name: tivision_apps
      Description: TI J722S 4GB EdgeAI OpenVX runtime
      Version: ${release.sdk.version}
      Libs: -L$out/lib -ltivision_apps
      Cflags: -I$dev/include -I$dev/include/ti-edgeai/app_utils -I$dev/include/ti-edgeai/vision_apps
      EOF
      test -s "$out/lib/libtivision_apps.so.11.2.0"
      readelf -d "$out/lib/libtivision_apps.so.11.2.0" | grep SONAME
      runHook postInstall
    '';
    passthru = {
      inherit rpmsg manifest;
      memoryMap = "j722s-4gb-edgeai";
      firmwareVersion = release.sdk.version;
    };
    meta = {
      description = "TI J722S OpenVX/vision-apps MPU runtime matched to the 4GB EdgeAI firmware";
      license =
        lib.licenses.unfreeRedistributable
        // {
          fullName = "TI source license and bundled third-party licenses; TI devices only";
        };
      platforms = ["aarch64-linux"];
    };
  }
