{
  stdenv,
  lib,
  fetchurl,
  fetchgit,
  callPackage,
  python3,
  perl,
  openssl,
  which,
  unzip,
  file,
}: let
  release = import ./accelerator-release.nix;
  tools =
    lib.genAttrs ["armllvm" "c7000" "sysconfig"] (tool:
      callPackage ./accelerator-tool.nix {inherit tool;});
  secdev = fetchgit release.secdev;
  patchFile = name:
    fetchurl {
      url = "https://raw.githubusercontent.com/TexasInstruments-Sandbox/ti-edgeai-armbian-build/${release.reference.revision}/patches/firmware/${name}";
      sha256 = release.reference.patches.${name};
    };
in
  stdenv.mkDerivation {
    pname = "beagley-ai-accelerator-firmware";
    inherit (release.sdk) version;
    src = fetchurl {inherit (release.sdk) url hash;};
    patches = [./accelerator-rtos-only.patch];
    nativeBuildInputs = [python3 perl openssl which unzip file];
    enableParallelBuilding = true;
    requiredSystemFeatures = ["big-parallel"];
    dontConfigure = true;
    dontStrip = true;
    dontFixup = true;
    postUnpack = ''
      rm -f "$sourceRoot"/tisdk-adas-image-j722s-evm.tar.xz "$sourceRoot"/boot-adas-j722s-evm.tar.gz
    '';
    buildPhase = ''
      runHook preBuild
      export PSDK_PATH="$PWD"
      export PSDK_TOOLS_PATH="$NIX_BUILD_TOP/ti-tools"
      export TOOLS_PATH="$PSDK_TOOLS_PATH"
      mkdir -p "$PSDK_TOOLS_PATH"
      ${lib.concatMapStringsSep "\n" (tool: ''
        ln -s ${tools.${tool}}/${tools.${tool}.directory} "$PSDK_TOOLS_PATH/${tools.${tool}.directory}"
      '') ["armllvm" "c7000" "sysconfig"]}
      ln -s ${secdev} core-secdev-k3
      # Version generation is offline; do not invoke the SDK setup script.
      make -C sdk_builder/scripts SOC=j722s BOARD=j722s_evm --no-print-directory get_component_versions > .component_versions_j722s_env
      patchShebangs sdk_builder vision_apps app_utils tiovx imaging video_io mcu_plus_sdk_j722s_11_02_01_05
      makeArgs=(
        SOC=j722s TISDK_IMAGE=edgeai PROFILE=release HS=0
        BUILD_ENABLE_ETHFW=no BUILD_LINUX_MPU=no BUILD_CPU_MPU1=no
        BUILD_QNX_MPU=no BUILD_APP_RTOS_LINUX=yes BUILD_EMULATION_MODE=no
        "ENABLED_IPC_CORES=ENABLE_IPC_MPU1 ENABLE_IPC_MCU2_0 ENABLE_IPC_C7x_1 ENABLE_IPC_C7x_2"
        SUPRESS_WARNINGS_FLAG=-Wno-nonportable-include-path
      )
      # TI's scrub graph has overlapping removals and requires serial execution.
      make -C sdk_builder -j1 -f Makefile -f ${patchFile "j722s-sdk-scrub-workaround.mk"} "''${makeArgs[@]}" sdk_scrub
      patch -d vision_apps -p1 < ${patchFile "j722s-4gb-edgeai-memory-map.patch"}
      patch -d vision_apps -p1 < ${patchFile "j722s-edgeai-disable-cpsw.patch"}
      (
        cd vision_apps/platform/j722s/rtos
        PYTHONPATH="$PSDK_PATH/vision_apps/tools/PyTI_PSDK_RTOS" python3 gen_linker_mem_map.py
        grep -q 'DDR_SHARED_MEM_PHYS_ADDR (0x8A0000000u)' app_mem_map.h
        grep -q 'reg = <0x08 0xa0000000 0x00 0x20000000>' k3-j722s-rtos-memory-map.dtsi
        for core in c7x_1 c7x_2; do
          cp "$core/freertos.syscfg" "$core/freertos_no_board_deps.syscfg"
        done
        if grep -n '0x900000000' c7x_1/*.syscfg c7x_2/*.syscfg mcu2_0/*.syscfg; then
          echo "Invalid 8 GiB firmware memory layout" >&2
          exit 1
        fi
      )
      make -C sdk_builder -j"$NIX_BUILD_CORES" "''${makeArgs[@]}" firmware
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/firmware/beagley-ai" "$out/share/beagley-ai"
      for core in mcu2_0 c7x_1 c7x_2; do
        firmware="psdk_fw/j722s/vision_apps_eaik/vx_app_rtos_linux_$core.out"
        test -s "$firmware"
        readelf -h "$firmware"
        readelf -S "$firmware" | grep -q '.resource_table'
        install -m444 "$firmware" "$out/lib/firmware/beagley-ai/"
      done
      # Explicit application-core aliases only; never replace system DM firmware.
      ln -s beagley-ai/vx_app_rtos_linux_mcu2_0.out "$out/lib/firmware/j722s-main-r5f0_0-fw"
      ln -s beagley-ai/vx_app_rtos_linux_c7x_1.out "$out/lib/firmware/j722s-c71_0-fw"
      ln -s beagley-ai/vx_app_rtos_linux_c7x_2.out "$out/lib/firmware/j722s-c71_1-fw"
      install -m444 vision_apps/platform/j722s/rtos/{app_mem_map.h,k3-j722s-rtos-memory-map.dtsi} "$out/share/beagley-ai/"
      mkdir -p "$out/share/licenses/beagley-ai-accelerator-firmware"
      find . -type f \( -iname '*manifest*.html' -o -iname 'license*' -o -iname 'licence*' -o -name '*.spdx' \) -print0 |
        while IFS= read -r -d $'\0' notice; do
          install -Dm444 "$notice" "$out/share/licenses/beagley-ai-accelerator-firmware/$notice"
        done
      sha256sum "$out"/lib/firmware/beagley-ai/*.out > "$out/share/beagley-ai/SHA256SUMS"
      runHook postInstall
    '';
    meta = {
      description = "Source-built J722S application R5/C7x firmware with BeagleY-AI 4 GiB ABI and Linux-owned Ethernet";
      platforms = ["x86_64-linux"];
      license = lib.licenses.unfree;
    };
  }
