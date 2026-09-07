{
  stdenv,
  lib,
  fetchurl,
  glibc,
  python3,
  binutils,
  makeWrapper,
  zlib,
  ncurses5,
  tool,
}: let
  release = (import ./accelerator-release.nix).tools.${tool};
  libraries = lib.makeLibraryPath [glibc stdenv.cc.cc.lib zlib ncurses5];
  loader = "${glibc}/lib/ld-linux-x86-64.so.2";
in
  stdenv.mkDerivation {
    pname = "beagley-ai-accelerator-${tool}";
    inherit (release) version;
    src = fetchurl {inherit (release) url hash;};
    dontUnpack = true;
    dontFixup = true;
    nativeBuildInputs = [python3 binutils makeWrapper];
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/original"
      # TI's binary redistribution terms require the installed payload to remain
      # unchanged. Neither the installer nor its output is patched or stripped.
      ${loader} --library-path ${libraries} "$src" --mode unattended \
        --prefix "$out/lib/original${lib.optionalString (tool == "sysconfig") "/${release.directory}"}"
      export toolOriginal="$out/lib/original/${release.directory}"
      export toolView="$out/${release.directory}"
      python3 - <<'PY'
      import hashlib, os, pathlib, subprocess
      original = pathlib.Path(os.environ['toolOriginal'])
      view = pathlib.Path(os.environ['toolView'])
      assert original.is_dir(), original
      hashes = []
      for root, directories, files in os.walk(original):
          relative = pathlib.Path(root).relative_to(original)
          (view / relative).mkdir(parents=True, exist_ok=True)
          for name in files:
              source = pathlib.Path(root) / name
              target = view / relative / name
              target.symlink_to(source)
              if not source.is_symlink():
                  hashes.append(hashlib.sha256(source.read_bytes()).hexdigest() + '  ' + str(source.relative_to(original)))
              if source.is_file() and os.access(source, os.X_OK) and source.open('rb').read(4) == b'\x7fELF':
                  headers = subprocess.run(['readelf', '-l', str(source)], capture_output=True, text=True, check=True).stdout
                  if 'INTERP' in headers:
                      target.unlink()
                      # Preserve argv[0] so compiler drivers discover the wrapper
                      # view when launching their bundled compiler subprocesses.
                      extra = ""
                      if name == 'tiarmclang':
                          resources = list((original / 'lib/clang').iterdir())
                          assert len(resources) == 1, resources
                          extra = ' -no-canonical-prefixes -resource-dir ' + repr(str(resources[0])) + ' -B' + repr(str(view / 'bin'))
                      prefix = "" if name != 'tiarmclang' else 'case "$1" in -cc1|-cc1as) exec ${loader} --library-path ${libraries} ' + repr(str(source)) + ' "$@";; esac\n'
                      target.write_text('#!${stdenv.shell}\n' + prefix + 'exec ${loader} --argv0 ' + repr(str(target)) + ' --library-path ' + repr(str(source.parent) + ':${libraries}') + ' ' + repr(str(source)) + extra + ' "$@"\n')
                      target.chmod(0o755)
      manifest = pathlib.Path(os.environ['out']) / 'vendor-payload.sha256'
      manifest.write_text('\n'.join(sorted(hashes)) + '\n')
      PY
      (cd "$toolOriginal"; sha256sum --quiet --check "$out/vendor-payload.sha256")
      runHook postInstall
    '';
    passthru = {inherit (release) directory;};
    meta = {
      description = "Unmodified TI ${tool} host payload with loader wrappers for offline J722S RTOS builds";
      platforms = ["x86_64-linux"];
      license = lib.licenses.unfree;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
