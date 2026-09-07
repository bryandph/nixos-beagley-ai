{
  provider = "beagle-ti-6.12-psdk-11.02";
  board = {
    compatible = "beagle,am67a-beagley-ai";
    dtb = "ti/k3-am67a-beagley-ai.dtb";
    console = "ttyS2,115200n8";
    securityVariant = "hs-fs";
    # Confirm the actual device variant over serial before hardware acceptance.
    securityVariantVerified = false;
  };
  sources = {
    kernel = {
      owner = "beagleboard";
      repo = "linux";
      rev = "8fb21420a704ea36aaf66df8288ed8ee9da2762d";
      hash = "sha256-eNoreZyo7GCWGAi0eYQX3Ui34LqsDsyrbViYdxr/DcU=";
    };
    firmware = {
      owner = "TexasInstruments";
      repo = "ti-linux-firmware";
      rev = "d528873a75e532075a1fd5d2a53defef98d60437";
      hash = "sha256-uHdC0QgMCJ3C6BCIINY9InQkxvH4c82mNa4bgdihl48=";
    };
    uboot = {
      owner = "beagleboard";
      repo = "u-boot";
      rev = "a2b9f59b4fa23266d014c8bf45baeaa189630355";
      hash = "sha256-u/4vYhwY9Sdv8IbmnvkH6nUX44sAltmsN7iMDitZgj8=";
    };
    tfA = {
      owner = "TexasInstruments";
      repo = "arm-trusted-firmware";
      rev = "b11beb2b6bd30b75c4bfb0e9925c0e72f16ca53f";
      hash = "sha256-of5+mD5Plb12pIsx0yqk8warV3MhV3fJJZtFcxKCyM8=";
    };
    optee = {
      owner = "OP-TEE";
      repo = "optee_os";
      rev = "8aead28cc4df095c53d33841f6c0041eed0d0084";
      hash = "sha256-4z706DNfZE+CAPOa362CNSFhAN1KaNyKcI9C7+MRccs=";
    };
    armbian = {
      owner = "armbian";
      repo = "build";
      rev = "d3298cac2223892b668ab27e95237448eeb75f26";
      hash = "sha256-Eq3pEAvmXkuS/wZRc9qKpLGGA6OIyCB/Q0rqQIzl9C8=";
    };
  };
  firmware = {
    version = "11.02.15";
    licenseFile = "LICENSE.ti";
    members = [
      {
        path = "ti-sysfw/ti-fs-firmware-j722s-hs-fs-enc.bin";
        size = 159744;
        sha256 = "5e99c9b715f50b8b9d8e17ced06b0e198fecb8040d4d0ee55233ad6eeedabd87";
      }
      {
        path = "ti-sysfw/ti-fs-firmware-j722s-hs-fs-cert.bin";
        size = 1684;
        sha256 = "78e7b201d3099caeda67d5e609b909068fe98e7413e712408859bea6c26352a8";
      }
      {
        path = "ti-dm/j722s/ipc_echo_testb_mcu1_0_release_strip.xer5f";
        size = 138484;
        sha256 = "412e2805a03d2057f5570e47320e81df7db04a3f6ebe91c7044622a5f134e096";
      }
    ];
    publicationPolicy = "Unmodified binaries for TI devices only; preserve LICENSE.ti and copyright notices.";
  };
  kernel = {
    version = "6.12.49";
    patchDirectory = "patch/kernel/archive/k3-beagle-6.12";
    patches = [
      "0001-arm64-dts-ti-k3-am67a-beagley-ai-include-armbian-supplement.patch"
      "0001-libbpf-const-correctness-for-newer-glibc.patch"
      "0002-arm64-dts-ti-build-BeagleY-AI-EdgeAI-DTBs.patch"
    ];
    config = "config/kernel/linux-k3-beagle-vendor.config";
  };
  boot = {
    ubootVersion = "2025.07";
    tfAVersion = "11.00.09";
    opteeVersion = "4.6.0";
    r5Defconfig = "am67a_beagley_ai_r5_defconfig";
    a53Defconfig = "am67a_beagley_ai_a53_defconfig";
    # This is the payload used by the selected Armbian/BeagleBoard tuple.
    opteePayload = "tee-pager_v2.bin";
    tfAPlatform = "k3";
    tfABoard = "lite";
    opteePlatform = "k3-am62x";
  };
}
