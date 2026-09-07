{
  profiles = {
    boardWiring = {
      owner = "beagleboard";
      repo = "linux";
      rev = "ac5c6fe561c328dc989be8c9e45c31ad775abba9";
      directory = "arch/arm64/boot/dts/ti";
      license = "GPL-2.0-only";
    };
    # CSI0 derives from the release.nix Armbian source. OLDI uses the selected
    # 6.12 BeaglePlay transmitter graph with BeagleY-specific connector wiring.
    adaptation = "Remove build timestamps; use GPIO hogs for the CSI1/DSI mux; adapt OLDI graph to the provider kernel; add explicit profile resource claims.";
  };
  codec = {
    version = "11.02.15";
    rev = "d528873a75e532075a1fd5d2a53defef98d60437";
    firmware = {
      path = "cnm/wave521c_k3_codec_fw.bin";
      size = 999104;
      sha256 = "e77e73a5379b93ba5ae208ff91480f832a89d47eaf1ec42c88f6bcf86cff1fd8";
    };
    license = {
      path = "LICENCE.cnm";
      sha256 = "88236d5ae45b7abc96c2ab4c6952af88758e24b17412dd173746ee1c559b3c6f";
    };
    publicationPolicy = "Unmodified Wave521C firmware for TI silicon only; preserve LICENCE.cnm. E5010 has no separate firmware.";
    jpegInterruptFix = {
      rev = "a4d7dcd55304001db2f70268562d12017aae2527";
      url = "https://github.com/TexasInstruments/ti-linux-kernel/commit/a4d7dcd55304001db2f70268562d12017aae2527.patch";
      sha256 = "01070e3c6ce4f587e60c29b13e47accd6642c155135b48dd96fefe440a6c7c66";
      issue = "https://sir.ext.ti.com/jira/browse/EXT_EP-13139";
      license = "GPL-2.0-only OR MIT";
    };
  };
  rogue = {
    mesa = {
      version = "24.0.1";
      rev = "68af6a102c2298569e77d1aa8bccc1ff61438b3e";
      sha256 = "a03c5626c33dd1bb6c53c7fc061cd00fe13046ff5e4044ddb7753df8d644809c";
      authority = "https://github.com/TexasInstruments/meta-ti/blob/7ff810824442c56ef59fa2d705d64a03ade5f5f7/meta-ti-bsp/recipes-graphics/mesa/mesa-pvr_24.0.1.bb";
    };
    version = "25.2.6850647";
    bvnc = "36.53.104.796";
    buildDirectory = "j722s_linux";
    # Upstream j722s_linux is a symlink to am62p_linux, not J784S4.
    underlyingBuildDirectory = "am62p_linux";
    userspaceDirectory = "targetfs/j722s_linux/lws-generic/release";
    kmd = {
      rev = "a838ac0074db640ebd1b64be6364417b1bbca3cd";
      sha256 = "63cadd0c12f5d6b1253c03d7d23ee45078354a85ce69b4bbd7867203e82cac34";
    };
    userspace = {
      rev = "adcbb5c620ff172da4152c02a2fee8f42dc4c472";
      sha256 = "e6680f6a0f7687ad0c7accb46e8707aa4fcd1085e20e03902cc8ff9992bc9da8";
    };
    publicationPolicy = "KMD is MIT OR GPL-2.0-only; userspace and firmware are unmodified TI-device-only binaries under upstream LICENSE. Do not patchelf or strip vendor payloads.";
  };
}
