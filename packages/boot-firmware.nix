{
  fetchurl,
  lib,
  runCommand,
}: let
  release = import ./release.nix;
  fetchMember = member:
    fetchurl {
      url = "https://git.ti.com/cgit/processor-firmware/ti-linux-firmware/plain/${member.path}?id=${release.sources.firmware.rev}";
      sha256 = member.sha256;
    };
  licenseFile = fetchMember {
    path = "LICENSE.ti";
    sha256 = "ab20ffbe7bba7e94be246b3417d33a914b3f07c16c47ef5a7f7602349a666a61";
  };
  whence = fetchMember {
    path = "WHENCE";
    sha256 = "412d8ae4acb9f3281afb9313ee3f3dc6100aebfe42a6c21149d10a3d28048b03";
  };
  license =
    lib.licenses.unfreeRedistributable
    // {
      shortName = "TI-TSPA";
      fullName = "TI limited license (unmodified binaries for TI devices)";
      url = "https://github.com/TexasInstruments/ti-linux-firmware/blob/${release.sources.firmware.rev}/LICENSE.ti";
    };
in
  runCommand "beagley-ai-boot-firmware-${release.firmware.version}" {
    passthru = {
      provenance = release.sources.firmware;
      inherit (release.firmware) members publicationPolicy;
    };
    meta = {
      inherit license;
      description = "Reviewed J722S HS-FS TIFS and system Device Manager firmware";
      sourceProvenance = [lib.sourceTypes.binaryFirmware];
    };
  } ''
    ${lib.concatMapStringsSep "\n" (member: ''
        test "$(wc -c < ${fetchMember member})" -eq ${toString member.size}
        echo '${member.sha256}  ${fetchMember member}' | sha256sum -c -
        install -Dm444 ${fetchMember member} "$out/${member.path}"
      '')
      release.firmware.members}
    install -Dm444 ${licenseFile} "$out/share/licenses/beagley-ai-boot-firmware/LICENSE.ti"
    install -Dm444 ${whence} "$out/share/licenses/beagley-ai-boot-firmware/WHENCE"
  ''
