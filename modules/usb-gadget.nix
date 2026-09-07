{config, ...}: {
  flake.modules.nixos.beagley-ai-usb-gadget = {pkgs, ...}: let
    gadget = pkgs.writeShellApplication {
      name = "beagley-usb-gadget";
      runtimeInputs = [pkgs.coreutils];
      text = builtins.readFile ../packages/usb-gadget.sh;
    };
  in {
    imports = [config.flake.modules.nixos.beagley-ai-resources];
    hardware.beagleyAi.resourceClaims."usb:usb0" = ["acm-ecm-gadget"];
    hardware.deviceTree.overlays = [
      {
        name = "beagley-ai-usb-device";
        filter = "k3-am67a-beagley-ai";
        dtsText = ''
          /dts-v1/;
          /plugin/;
          / { compatible = "beagle,am67a-beagley-ai"; };
          &usb0 { dr_mode = "peripheral"; };
        '';
      }
    ];
    boot.kernelModules = ["libcomposite" "usb_f_acm" "usb_f_ecm"];
    systemd.services.beagley-usb-gadget = {
      description = "BeagleY-AI USB-C serial and Ethernet gadget";
      wantedBy = ["multi-user.target"];
      requires = ["sys-kernel-config.mount"];
      after = ["sys-kernel-config.mount" "systemd-modules-load.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 45;
        ExecStart = "${gadget}/bin/beagley-usb-gadget start";
        ExecStop = "${gadget}/bin/beagley-usb-gadget stop";
      };
    };
  };
}
