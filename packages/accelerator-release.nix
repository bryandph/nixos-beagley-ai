{
  abi = {
    sharedMemory = {
      base = "0x8a0000000";
      size = "0x20000000";
    };
    applicationCores = {
      mcu2_0 = {
        alias = "j722s-main-r5f0_0-fw";
        resourceTable = "0xa2100000";
        entry = "0x0";
        memoryRegion = "vision_apps_main_r5fss0_core0_memory_region";
      };
      c7x_1 = {
        alias = "j722s-c71_0-fw";
        resourceTable = "0xad100000";
        entry = "0xad200000";
        memoryRegion = "vision_apps_c71_0_memory_region";
      };
      c7x_2 = {
        alias = "j722s-c71_1-fw";
        resourceTable = "0xb1100000";
        entry = "0xb1200000";
        memoryRegion = "vision_apps_c71_1_memory_region";
      };
    };
  };
  sdk = {
    version = "11.02.01.03";
    url = "https://dr-download.ti.com/software-development/software-development-kit-sdk/MD-1bSfTnVt5d/11.02.01.03/ti-processor-sdk-rtos-j722s-evm-11_02_01_03.tar.gz";
    hash = "sha256-TH+7DlbufsLCBbR4mIObLzfQn1OeZ6iGataGc05WKqk=";
  };
  secdev = {
    url = "https://git.ti.com/git/security-development-tools/core-secdev-k3.git";
    rev = "ed6951fd3877c6cac7f1237311f7278ac21634f3";
    hash = "sha256-299NQu+Ql11E97o0xPrU/LZX6fP6DuuhYYPlRrXpPNY=";
  };
  reference = {
    revision = "be3a57d2760691f6b4f5cc7cae6e00ccddef7016";
    patches = {
      "j722s-4gb-edgeai-memory-map.patch" = "a52a3c0f8640485046556a0f4c8a06aec1bde5d8afeba3db7dfbc3fb74e354c4";
      "j722s-edgeai-disable-cpsw.patch" = "3ebb3291612ec8bc6c03802f97cd84adf40a51c74437fa2a8f807cd133853f4e";
      "j722s-sdk-scrub-workaround.mk" = "b2f34e5a0fb1cae2cc3bfc00fef033e9addb59505605bf5b7220db61f2b02903";
    };
  };
  tools = {
    armllvm = {
      version = "4.0.4.LTS";
      url = "https://dr-download.ti.com/software-development/ide-configuration-compiler-or-debugger/MD-ayxs93eZNN/4.0.4.LTS/ti_cgt_armllvm_4.0.4.LTS_linux-x64_installer.bin";
      hash = "sha256-mMYOzCWaB6VL5vzA9VmQMy9JO/5drUYMC6g5Y/XcsG8=";
      directory = "ti-cgt-armllvm_4.0.4.LTS";
    };
    c7000 = {
      version = "5.0.0.LTS";
      url = "https://dr-download.ti.com/software-development/ide-configuration-compiler-or-debugger/MD-707zYe3Rik/5.0.0.LTS/ti_cgt_c7000_5.0.0.LTS_linux-x64_installer.bin";
      hash = "sha256-AGefhScyrSPOqX5vo2SNfC2ayibCREUeiwepHB0g7n8=";
      directory = "ti-cgt-c7000_5.0.0.LTS";
    };
    sysconfig = {
      version = "1.26.2.4477";
      url = "https://dr-download.ti.com/software-development/ide-configuration-compiler-or-debugger/MD-nsUM6f7Vvb/1.26.2.4477/sysconfig-1.26.2_4477-setup.run";
      hash = "sha256-mhQq8eq8Ft/1EF0RQWP8LZzfsLITtROdQvmoAoVXfk8=";
      directory = "sysconfig_1.26.2";
    };
  };
}
