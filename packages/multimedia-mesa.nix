{
  lib,
  stdenv,
  fetchurl,
  meson,
  ninja,
  pkg-config,
  python3,
  bison,
  flex,
  libdrm,
  expat,
  zlib,
  zstd,
  wayland,
  wayland-protocols,
  wayland-scanner,
  libglvnd,
}: let
  release = (import ./multimedia-release.nix).rogue.mesa;
in
  stdenv.mkDerivation {
    pname = "beagley-ai-pvr-mesa";
    inherit (release) version;
    src = fetchurl {
      url = "https://gitlab.freedesktop.org/StaticRocket/mesa/-/archive/${release.rev}/mesa-${release.rev}.tar.gz";
      inherit (release) sha256;
    };
    nativeBuildInputs = [meson ninja pkg-config bison flex wayland-scanner (python3.withPackages (p: [p.mako p.pyyaml p.packaging]))];
    buildInputs = [libdrm expat zlib zstd wayland wayland-protocols libglvnd];
    mesonFlags = [
      "-Dauto_features=auto"
      "-Dgallium-drivers=pvr"
      "-Dvulkan-drivers=pvr"
      "-Dplatforms=wayland"
      "-Degl=enabled"
      "-Dgbm=enabled"
      "-Dglvnd=true"
      "-Dglx=disabled"
      "-Dgles1=enabled"
      "-Dgles2=enabled"
      "-Dxlib-lease=disabled"
      "-Dllvm=disabled"
      "-Dshared-llvm=disabled"
      "-Dvalgrind=disabled"
      "-Dgallium-vdpau=disabled"
      "-Dgallium-va=disabled"
      "-Dgallium-xa=disabled"
      "-Dgallium-nine=false"
      "-Dgallium-opencl=disabled"
      "-Dgallium-rusticl=false"
      "-Dlmsensors=disabled"
      "-Dbuild-tests=false"
      "-Dvideo-codecs="
    ];
    postInstall = ''
      install -Dm444 ../docs/license.rst "$out/share/licenses/beagley-ai-pvr-mesa/license.rst"
    '';
    passthru.provenance = release;
    meta = {
      description = "TI-selected Mesa EGL, GBM and Vulkan WSI shims for the Rogue DDK";
      license = lib.licenses.mit;
      platforms = ["aarch64-linux"];
    };
  }
