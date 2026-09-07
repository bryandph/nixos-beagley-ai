{
  lib,
  runCommand,
  fetchurl,
}: let
  release = import ./accelerator-ipc-release.nix;
  fetchMember = path: sha256:
    fetchurl {
      url = "https://git.ti.com/cgit/processor-firmware/ti-linux-firmware/plain/${path}?id=${release.revision}";
      inherit sha256;
    };
in
  runCommand "beagley-ai-ipc-firmware-${release.version}" {
    meta = {
      description = "Narrow J722S application-core IPC echo firmware, excluding Device Manager";
      license = lib.licenses.unfreeRedistributable;
      sourceProvenance = [lib.sourceTypes.binaryFirmware];
    };
  } ''
    mkdir -p "$out/lib/firmware/ti-ipc/j722s"
    ${lib.concatMapStringsSep "\n" (member: let
        source = fetchMember "ti-ipc/j722s/${member.file}" member.sha256;
      in ''
        echo '${member.sha256}  ${source}' | sha256sum -c -
        install -m444 ${source} "$out/lib/firmware/ti-ipc/j722s/${member.file}"
        ln -s "ti-ipc/j722s/${member.file}" "$out/lib/firmware/${member.alias}"
      '')
      release.members}
    install -Dm444 ${fetchMember "LICENSE.ti" "ab20ffbe7bba7e94be246b3417d33a914b3f07c16c47ef5a7f7602349a666a61"} "$out/share/licenses/beagley-ai-ipc-firmware/LICENSE.ti"
    install -Dm444 ${fetchMember "WHENCE" "412d8ae4acb9f3281afb9313ee3f3dc6100aebfe42a6c21149d10a3d28048b03"} "$out/share/licenses/beagley-ai-ipc-firmware/WHENCE"
  ''
