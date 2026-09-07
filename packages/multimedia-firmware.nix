{
  fetchurl,
  lib,
  runCommand,
}: let
  release = (import ./multimedia-release.nix).codec;
  fetchMember = member:
    fetchurl {
      name = builtins.baseNameOf member.path;
      url = "https://git.ti.com/cgit/processor-firmware/ti-linux-firmware/plain/${member.path}?id=${release.rev}";
      inherit (member) sha256;
    };
  firmware = fetchMember release.firmware;
in
  runCommand "beagley-ai-codec-firmware-${release.version}" {
    passthru.provenance = release;
    meta = {
      description = "Matched TI Wave521C codec firmware (E5010 requires no blob)";
      license =
        lib.licenses.unfreeRedistributable
        // {
          fullName = "Chips&Media firmware license for TI silicon";
          url = "https://git.ti.com/cgit/processor-firmware/ti-linux-firmware/plain/LICENCE.cnm?id=${release.rev}";
        };
      sourceProvenance = [lib.sourceTypes.binaryFirmware];
    };
  } ''
    test "$(wc -c < ${firmware})" -eq ${toString release.firmware.size}
    echo '${release.firmware.sha256}  ${firmware}' | sha256sum -c -
    install -Dm444 ${firmware} "$out/lib/firmware/${release.firmware.path}"
    install -Dm444 ${fetchMember release.license} "$out/share/licenses/beagley-ai-codec-firmware/LICENCE.cnm"
  ''
