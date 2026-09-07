{
  lib,
  runCommand,
  fetchgit,
  callPackage,
  python3,
}: let
  runtime = callPackage ./accelerator-runtime.nix {};
  imaging = builtins.head (builtins.filter (project: project.path == "imaging") runtime.manifest);
  source = fetchgit {inherit (imaging) url rev hash;};
in
  runCommand "beagley-ai-imx219-dcc-11.02.01.03" {
    nativeBuildInputs = [python3];
    meta = {
      description = "Unmodified mode-specific IMX219 RAW10 ISP/2A tuning from matched TI imaging";
      license = lib.licenses.unfreeRedistributable;
      sourceProvenance = [lib.sourceTypes.binaryFirmware];
    };
  } ''
    mkdir -p "$out/share/beagley-ai/imx219" "$out/share/licenses/beagley-ai-imx219-dcc"
    python3 - ${source} "$out" ${./multimedia-imx219-dcc.json} <<'PY'
    import hashlib, json, pathlib, shutil, sys
    source, out, manifest = map(pathlib.Path, sys.argv[1:])
    destination = out / 'share/beagley-ai/imx219'
    for mode, members in json.loads(manifest.read_text()).items():
        for member in members.values():
            original = source / 'sensor_drv/src/imx219/dcc_bins/linear' / member['file']
            data = original.read_bytes()
            assert len(data) == member['size']
            assert hashlib.sha256(data).hexdigest() == member['sha256']
            shutil.copyfile(original, destination / original.name)
            assert (destination / original.name).read_bytes() == data
    shutil.copyfile(manifest, destination / 'modes.json')
    PY
    cp ${source}/docs/manifest/Imaging_manifest.html "$out/share/licenses/beagley-ai-imx219-dcc/"
    cp ${./accelerator-runtime-sources.json} "$out/share/beagley-ai/imx219/source-manifest.json"
  ''
