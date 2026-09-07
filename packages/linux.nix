{
  buildLinux,
  fetchFromGitHub,
  lib,
  runCommand,
  ...
}: let
  release = import ./release.nix;
  reference = fetchFromGitHub release.sources.armbian;
in
  (buildLinux {
    pname = "linux-beagley-ai";
    inherit (release.kernel) version;
    modDirVersion = release.kernel.version;
    src = runCommand "beagley-ai-kernel-source" {} ''
      cp -r ${fetchFromGitHub release.sources.kernel} "$out"
      chmod -R u+w "$out"
      cp ${reference}/${release.kernel.config} "$out/arch/arm64/configs/beagley_ai_defconfig"
      cp ${reference}/${release.kernel.patchDirectory}/dt/* "$out/arch/arm64/boot/dts/ti/"
      cp ${./k3-am67a-beagley-ai-cpu-cooling.dtsi} "$out/arch/arm64/boot/dts/ti/k3-am67a-beagley-ai-cpu-cooling.dtsi"
      chmod u+w "$out/arch/arm64/boot/dts/ti/k3-am67a-beagley-ai-armbian.dtsi"
      cat >> "$out/arch/arm64/boot/dts/ti/k3-am67a-beagley-ai-armbian.dtsi" <<'EOF'
      #include "k3-am67a-beagley-ai-cpu-cooling.dtsi"
      EOF
    '';
    defconfig = "beagley_ai_defconfig";
    autoModules = false;
    # Keep the board vendor defconfig; the generic desktop defaults reference
    # dependencies deliberately absent here. Required NixOS options are explicit.
    enableCommonConfig = false;
    kernelPatches =
      map (name: {
        inherit name;
        patch = "${reference}/${release.kernel.patchDirectory}/${name}";
      })
      release.kernel.patches;
    structuredExtraConfig = with lib.kernel; {
      ARCH_K3 = yes;
      TI_K3_AM65_CPSW_NUSS = yes;
      MMC_SDHCI_AM654 = yes;
      SERIAL_8250_CONSOLE = yes;
      BLK_DEV_NVME = module;
      PCI_J721E_HOST = yes;
      # Own hub power/reset before enumeration, avoiding a late module reset.
      USB_ONBOARD_DEV = yes;
      CPU_FREQ = yes;
      CPUFREQ_DT = yes;
      CPUFREQ_DT_PLATDEV = yes;
      CPU_THERMAL = yes;
      THERMAL_GOV_STEP_WISE = yes;
      CGROUPS = yes;
      NAMESPACES = yes;
      INOTIFY_USER = yes;
      SIGNALFD = yes;
      TIMERFD = yes;
      EPOLL = yes;
      FHANDLE = yes;
      SECCOMP = yes;
      SECCOMP_FILTER = yes;
      # NixOS's default firewall installs an IPv4 rpfilter rule at startup.
      IP_NF_MATCH_RPFILTER = module;
      UNIX = yes;
      BINFMT_ELF = yes;
      BINFMT_SCRIPT = yes;
      TMPFS = yes;
      TMPFS_POSIX_ACL = yes;
      DEVTMPFS = yes;
      DEVTMPFS_MOUNT = yes;
      BLK_DEV_INITRD = yes;
      EXT4_FS = yes;
      VFAT_FS = yes;
      # Application remote processors stay offline without selected firmware.
      TI_K3_R5_REMOTEPROC = module;
      TI_K3_DSP_REMOTEPROC = module;
    };
    extraMeta = {platforms = ["aarch64-linux"];};
    extraPassthru = {provider = release.provider;};
  }).overrideAttrs (_: {
    requiredSystemFeatures = ["big-parallel"];
  })
