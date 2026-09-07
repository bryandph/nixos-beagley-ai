{
  config,
  lib,
  pkgs,
  ...
}: let
  profile = config.hardware.beagleyAi.remoteprocOwner;
  lifecycle = pkgs.callPackage ../../../packages/accelerator-remoteproc.nix {inherit profile;};
in {
  options.hardware.beagleyAi.remoteprocOwner = lib.mkOption {
    type = lib.types.enum ["ipc" "vision"];
    internal = true;
    description = "Exclusive application remote-processor firmware ownership, selected by feature composition";
  };
  config = {
    system.build.beagleyAiAcceleratorKernelCheck = pkgs.callPackage ../../../packages/accelerator-kernel-check.nix {
      kernel = config.boot.kernelPackages.kernel;
      inherit profile;
    };
    system.extraDependencies = [config.system.build.beagleyAiAcceleratorKernelCheck];
    environment.systemPackages = [lifecycle];
    systemd.services.beagley-ai-remoteproc = {
      description = "Start guarded BeagleY-AI application remote processors";
      wantedBy = ["multi-user.target"];
      after = ["systemd-udev-settle.service"];
      wants = ["systemd-udev-settle.service"];
      restartIfChanged = false;
      serviceConfig =
        {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${lifecycle}/bin/beagley-ai-remoteproc start";
          TimeoutStartSec = 90;
          TimeoutStopSec = 90;
        }
        // lib.optionalAttrs (profile == "ipc") {
          ExecStop = "${lifecycle}/bin/beagley-ai-remoteproc stop";
        };
    };
  };
}
