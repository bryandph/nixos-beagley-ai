{
  lib,
  stdenv,
  fetchgit,
  callPackage,
  meson,
  ninja,
  pkg-config,
  python3,
  gst_all_1,
}: let
  libraries = callPackage ./multimedia-edgeai-libraries.nix {};
  inherit (libraries) runtime;
  sdk = "${runtime.dev}/include/ti-edgeai";
  includes = ["tiovx/include" "tiovx/kernels/include" "tiovx/utils/include" "vision_apps" "vision_apps/utils/app_init/include" "vision_apps/kernels/img_proc/include" "vision_apps/kernels/fileio/include" "vision_apps/kernels/stereo/include" "video_io/kernels/include" "imaging/utils/itt_server/include" "app_utils" "imaging" "imaging/sensor_drv/include" "imaging/kernels/include" "imaging/algos/ae/include" "imaging/algos/awb/include" "imaging/algos/dcc/include" "imaging/ti_2a_wrapper/include" "psdk_include/ivision" "psdk_include/tidl_j7/arm-tidl/rt/inc" "psdk_include/tidl_j7/arm-tidl/tiovx_kernels/include" "psdk_include/vxlib/packages" "ti-perception-toolkit/include"];
in
  stdenv.mkDerivation {
    pname = "beagley-ai-edgeai-gstreamer";
    version = "0.7.0-sdk-11.02.01.03";
    src = fetchgit (libraries.sources.gst // {name = "source";});
    nativeBuildInputs = [meson ninja pkg-config python3];
    buildInputs = [libraries runtime runtime.rpmsg gst_all_1.gstreamer gst_all_1.gst-plugins-base];
    SOC = "j722s";
    NIX_CFLAGS_COMPILE = lib.concatStringsSep " " ((map (path: "-I${sdk}/${path}") includes) ++ (map (name: "-I${libraries}/include/edgeai-${name}") ["apps-utils" "tiovx-kernels" "tiovx-modules"]));
    postPatch = ''
      # TI's Yocto layer supplies virtual .pc files for components linked into
      # libtivision_apps. Declare the same real library dependencies explicitly.
      python3 - <<'PY'
      from pathlib import Path
      import re
      p = Path('meson.build')
      s = p.read_text()
      for name in ['imaging', 'tiovx', 'ti_vision_apps', 'ti_stereo_perception']:
          s = s.replace("dependency('" + name + "')", "declare_dependency(link_args: ['-ltivision_apps', '-lti_2a_wrapper'])")
      for name in ['edgeai_tiovx_modules', 'edgeai_tiovx_kernels', 'edgeai_apps_utils']:
          s = s.replace("dependency('" + name + "')", "declare_dependency(link_args: ['-l" + name.replace('_', '-') + "'])")
      # Upstream queries this even when its documented dl-plugins switch is off.
      s = s.replace("dependency('edgeai_dl_inferer')", "declare_dependency()")
      s = '\n'.join(line for line in s.splitlines() if 'shutil.copy(' not in line)
      p.write_text(s + '\n')
      # ISP implementation already has explicit J722S paths; its build/registry
      # gates still list only AM62A. Enable the shared VPAC path on this target.
      p = Path('ext/tiovx/meson.build')
      p.write_text(p.read_text().replace("if SOC == 'am62a'", "if SOC == 'am62a' or SOC == 'j722s'"))
      p = Path('ext/tiovx/gsttiovx.c')
      p.write_text(p.read_text().replace('#if defined(SOC_AM62A)', '#if defined(SOC_AM62A) || defined(SOC_J722S)'))
      # Inspection never creates a stream context; NULL is not an error to log.
      p = Path('gst-libs/gst/tiovx/gsttiovxmiso.c')
      p.write_text(p.read_text().replace('if (VX_SUCCESS == vxGetStatus ((vx_reference) priv->context))', 'if (priv->context != NULL && VX_SUCCESS == vxGetStatus ((vx_reference) priv->context))'))
      # GStreamer 1.26 exposes unpacked RAW10/12/16 with explicit le names.
      # Retain TI aliases and add the native caps to both ISP and format parser.
      for filename in ['ext/tiovx/gsttiovxisp.c', 'ext/tiovx/gsttiovxfc.c', 'gst-libs/gst/tiovx/gsttiovxutils.c']:
          p = Path(filename)
          text = p.read_text()
          for order in ['bggr', 'gbrg', 'grbg', 'rggb']:
              for depth in [10, 12, 16]:
                  old = order + str(depth)
                  text = text.replace('g_str_equal (gst_format, "' + old + '")', '(g_str_equal (gst_format, "' + old + '") || g_str_equal (gst_format, "' + old + 'le"))')
                  text = text.replace('(g_strcmp0 (format_str, "' + old + '") == 0)', '((g_strcmp0 (format_str, "' + old + '") == 0) || (g_strcmp0 (format_str, "' + old + 'le") == 0))')
                  text = re.sub(r'(?<=[ ,])' + old + r'(?=[ ,}])', old + ', ' + old + 'le', text)
          p.write_text(text)
      PY
    '';
    mesonFlags = ["-Ddl-plugins=disabled" "-Dtests=enabled" "-Dexamples=disabled" "-Ddoc=disabled"];
    # Test executables require the remote processor firmware and board hardware.
    doCheck = false;
    postInstall = ''
      mkdir -p "$out/share/licenses/beagley-ai-edgeai-gstreamer"
      cp ../LICENSE "$out/share/licenses/beagley-ai-edgeai-gstreamer/"
    '';
    passthru = {inherit libraries runtime;};
    meta = {
      description = "TI J722S TIOVX GStreamer ISP, scaler and vision plugins";
      license = lib.licenses.unfreeRedistributable;
      platforms = ["aarch64-linux"];
    };
  }
