{
  fetchurl,
  lib,
  runCommand,
  python3,
}: let
  release = import ./wireless-release.nix;
  fetchMember = member:
    fetchurl {
      url = "https://raw.githubusercontent.com/${release.source.owner}/${release.source.repo}/${release.source.rev}/${release.source.directory}/${member.name}";
      inherit (member) sha256;
    };
  licenseFile = fetchurl release.license;
in
  assert (import ./release.nix).sources.kernel.rev == release.driver.revision;
    runCommand "beagley-ai-wireless-firmware-${release.sdkVersion}" {
      nativeBuildInputs = [python3];
      passthru = {inherit release;};
      meta = {
        description = "Matched CC3301 Wi-Fi/BLE SDK firmware and board configuration";
        license = lib.licenses.unfreeRedistributable // {shortName = "TI-TSPA";};
        sourceProvenance = [lib.sourceTypes.binaryFirmware];
      };
    } ''
      ${lib.concatMapStringsSep "\n" (member: ''
          test "$(wc -c < ${fetchMember member})" -eq ${toString member.size}
          echo '${member.sha256}  ${fetchMember member}' | sha256sum -c -
          install -Dm444 ${fetchMember member} "$out/lib/firmware/ti-connectivity/${member.name}"
        '')
        release.members}
      install -Dm444 ${licenseFile} "$out/share/licenses/beagley-ai-wireless-firmware/LICENCE.ti-connectivity"
      python3 - "$out/lib/firmware/ti-connectivity/cc33xx-conf.bin" <<'PY'
      import pathlib, struct, sys
      data = pathlib.Path(sys.argv[1]).read_bytes()
      assert len(data) == ${toString release.driver.configSize}
      assert struct.unpack_from('<I4H', data) == (${toString release.driver.configMagic}, ${lib.concatMapStringsSep ", " toString release.driver.configVersion})
      assert data[${toString release.driver.bleEnableOffset}] == 1
      assert struct.unpack_from('<I', data, ${toString release.driver.baudOffset})[0] == ${toString release.driver.baudRate}
      assert data[${toString release.driver.flowControlOffset}] == 1
      PY
    ''
