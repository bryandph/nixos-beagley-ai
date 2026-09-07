{
  lib,
  stdenv,
  fetchurl,
  glibc,
  libdrm,
  wayland,
  makeWrapper,
  coreutils,
  callPackage,
}: let
  release = (import ./multimedia-release.nix).rogue;
  mesa = callPackage ./multimedia-mesa.nix {};
  runtimePath = lib.makeLibraryPath [mesa glibc libdrm wayland stdenv.cc.cc.lib];
in
  stdenv.mkDerivation {
    pname = "beagley-ai-rogue-userspace";
    inherit (release) version;
    src = fetchurl {
      url = "https://codeload.github.com/TexasInstruments/ti-img-rogue-umlibs/tar.gz/${release.userspace.rev}";
      name = "ti-img-rogue-umlibs-${release.userspace.rev}.tar.gz";
      inherit (release.userspace) sha256;
    };
    nativeBuildInputs = [makeWrapper];
    dontBuild = true;
    dontStrip = true;
    dontPatchELF = true;
    dontPatchShebangs = true;
    installPhase = ''
      runHook preInstall
      payload=${release.userspaceDirectory}
      mkdir -p "$out/lib" "$out/libexec" "$out/bin" "$out/share/vulkan/icd.d" "$out/etc/OpenCL/vendors"
      cp -a "$payload/usr/lib/." "$out/lib/"
      cp -a "$payload/lib/firmware" "$out/lib/"
      cp -a "$payload/usr/bin/." "$out/libexec/"
      install -Dm444 LICENSE "$out/share/licenses/beagley-ai-rogue-userspace/LICENSE"
      # Generated loader configuration and wrappers leave the licensed payload
      # untouched. No patchelf, stripping, or interpreter rewriting is permitted.
      cat > "$out/share/vulkan/icd.d/powervr_icd.json" <<EOF
      {"file_format_version":"1.0.0","ICD":{"library_path":"$out/lib/libVK_IMG.so","api_version":"1.4.314"}}
      EOF
      echo "$out/lib/libPVROCL.so" > "$out/etc/OpenCL/vendors/IMG.icd"
      for program in "$out"/libexec/*; do
        makeWrapper ${glibc}/lib/ld-linux-aarch64.so.1 "$out/bin/$(basename "$program")" \
          --add-flags "--library-path $out/lib:${runtimePath} $program" \
          --prefix LD_LIBRARY_PATH : "$out/lib:${runtimePath}"
      done
      makeWrapper ${coreutils}/bin/env "$out/bin/beagley-ai-gpu-run" \
        --prefix LD_LIBRARY_PATH : "$out/lib:${runtimePath}" \
        --set LIBGL_DRIVERS_PATH "${mesa}/lib/dri" \
        --set __EGL_VENDOR_LIBRARY_FILENAMES "${mesa}/share/glvnd/egl_vendor.d/50_mesa.json" \
        --set VK_DRIVER_FILES "$out/share/vulkan/icd.d/powervr_icd.json" \
        --set OCL_ICD_VENDORS "$out/etc/OpenCL/vendors"
      diff -r "$payload/usr/lib" "$out/lib" --exclude=firmware
      diff -r "$payload/lib/firmware" "$out/lib/firmware"
      diff -r "$payload/usr/bin" "$out/libexec"
      runHook postInstall
    '';
    passthru.provenance = release;
    meta = {
      description = "Unmodified TI J722S Rogue userspace and GPU firmware with Nix loader wrappers";
      license =
        lib.licenses.unfreeRedistributable
        // {
          fullName = "TI text file license (unmodified binaries for TI devices)";
          url = "https://github.com/TexasInstruments/ti-img-rogue-umlibs/blob/${release.userspace.rev}/LICENSE";
        };
      sourceProvenance = [lib.sourceTypes.binaryNativeCode lib.sourceTypes.binaryFirmware];
      platforms = ["aarch64-linux"];
    };
  }
