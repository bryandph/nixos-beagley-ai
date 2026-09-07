{...}: {
  flake.modules.nixos.beagley-ai-sd-image = {
    config,
    lib,
    pkgs,
    modulesPath,
    ...
  }: let
    bundle = pkgs.callPackage ../../../packages/boot-bundle.nix {};
  in {
    imports = [(modulesPath + "/installer/sd-card/sd-image.nix")];
    hardware.enableAllHardware = lib.mkForce false;
    # Initial recovery image intentionally owns only the SD. NVMe stays unmounted.
    fileSystems = lib.mkForce {
      "/" = {
        device = "/dev/disk/by-label/BEAGLEY_ROOT";
        fsType = "ext4";
      };
      "/boot" = {
        device = "/dev/disk/by-label/BEAGLEYBOOT";
        fsType = "vfat";
        options = ["umask=0077"];
      };
    };
    sdImage = {
      firmwareSize = 512;
      firmwarePartitionOffset = 8;
      firmwarePartitionID = "0x42474149";
      firmwarePartitionName = "BEAGLEYBOOT";
      rootVolumeLabel = "BEAGLEY_ROOT";
      populateRootCommands = "";
      populateFirmwareCommands = ''
        cp ${bundle}/{tiboot3.bin,tispl.bin,u-boot.img} firmware/
        cp -r ${bundle}/share firmware/
        ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d firmware
      '';
    };
    system.build.beagleyAiBootBundle = bundle;
    # K3 ROM needs the FAT partition active with partition type 0x0e.
    # Fail if the upstream image builder changes these construction points.
    system.build.beagleyAiSdImage = config.system.build.sdImage.overrideAttrs (old: let
      before = ["type=b\n" "type=83, bootable" "mkfs.vfat --invariant"];
      after = ["type=e, bootable\n" "type=83" "mkfs.vfat -F 16 --invariant"];
    in {
      buildCommand = assert lib.all (s: lib.hasInfix s old.buildCommand) before;
        lib.replaceStrings before after old.buildCommand;
    });
  };
}
