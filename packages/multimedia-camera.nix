{
  lib,
  runCommand,
  callPackage,
  makeWrapper,
  stdenv,
  pkg-config,
  gst_all_1,
}: let
  plugins = callPackage ./multimedia-edgeai-gstreamer.nix {};
  dcc = callPackage ./multimedia-imx219-dcc.nix {};
  osrt = callPackage ./accelerator-osrt.nix {};
  gstPaths = lib.makeSearchPath "lib/gstreamer-1.0" [plugins gst_all_1.gstreamer gst_all_1.gst-plugins-base gst_all_1.gst-plugins-good];
in
  runCommand "beagley-ai-camera-11.02.01.03" {
    nativeBuildInputs = [makeWrapper stdenv.cc pkg-config];
    buildInputs = [gst_all_1.gstreamer];
    passthru = {inherit plugins dcc osrt;};
    meta = {
      description = "IMX219 RAW10 ISP and contract-checked J722S inference tools";
      license = lib.licenses.mit;
      platforms = ["aarch64-linux"];
    };
  } ''
    mkdir -p "$out/bin"
    for tool in launch inspect; do
      makeWrapper ${gst_all_1.gstreamer}/bin/gst-$tool-1.0 "$out/bin/beagley-ai-gst-$tool" \
        --prefix GST_PLUGIN_PATH_1_0 : ${gstPaths}
    done
    $CC ${./multimedia-bayer-caps-check.c} $(pkg-config --cflags --libs gstreamer-1.0) \
      -L${plugins}/lib -Wl,-rpath,${plugins}/lib -lgsttiovx-1.0 -o bayer-caps-check
    GST_PLUGIN_PATH_1_0=${gstPaths} GST_REGISTRY_1_0="$TMPDIR/gst-registry.bin" ./bayer-caps-check
    makeWrapper ${osrt}/bin/beagley-ai-osrt-python "$out/bin/beagley-ai-camera-inference" \
      --add-flags ${./multimedia-camera-inference.py} \
      --prefix PATH : "$out/bin" \
      --set BEAGLEY_AI_IMX219_DCC ${dcc}/share/beagley-ai/imx219
  ''
