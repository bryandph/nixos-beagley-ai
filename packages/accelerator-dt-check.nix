{
  runCommand,
  python3,
  dtc,
  deviceTree,
  profile,
  firmware ? null,
}: let
  release = import ./release.nix;
  contract = {
    inherit profile;
    cores = (import ./accelerator-profiles.nix).${profile};
    memory =
      if profile == "vision"
      then import ./accelerator-memory.nix
      else {};
  };
in
  runCommand "beagley-ai-${profile}-device-tree-contract" {
    nativeBuildInputs = [python3 dtc];
    passAsFile = ["contract"];
    contract = builtins.toJSON contract;
  } ''
    python3 ${./accelerator-dt-check.py} ${deviceTree}/${release.board.dtb} "$contractPath" ${
      if firmware == null
      then "-"
      else "${firmware}/share/beagley-ai/k3-j722s-rtos-memory-map.dtsi"
    }
    mkdir "$out"
    cp "$contractPath" "$out/contract.json"
  ''
