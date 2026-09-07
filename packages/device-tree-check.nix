{
  runCommand,
  python3,
  dtc,
  deviceTree,
}: let
  release = import ./release.nix;
in
  runCommand "beagley-ai-device-tree-contract" {
    nativeBuildInputs = [python3 dtc];
  } ''
    python3 ${./device-tree-check.py} ${deviceTree}/${release.board.dtb} \
      ${toString release.kernel.cpuCooling.maximumFrequencyHz} \
      ${toString release.kernel.cpuCooling.passiveTemperatureMillicelsius} \
      ${toString release.kernel.cpuCooling.hysteresisMillicelsius}
    mkdir "$out"
    touch "$out/passed"
  ''
