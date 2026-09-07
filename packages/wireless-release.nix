{
  sdkVersion = "1.0.2.10";
  firmwareVersion = "1.7.0.316";
  source = {
    owner = "beagleboard";
    repo = "repos-arm64";
    rev = "fb0f6eccb2928b6e9d6c0dca5782f45939e85ae4";
    directory = "bbb.io-cc33xx-1.0.2.10-firmware/suite/trixie/debian";
  };
  # The board publisher's firmware package depends on firmware-ti-connectivity
  # for this TI license. Preserve the same unmodified notice from linux-firmware.
  license = {
    url = "https://gitlab.com/kernel-firmware/linux-firmware/-/raw/20250808/LICENCE.ti-connectivity";
    sha256 = "190fdf103278cd69f489dc0d1d4da81d9a36af8b5baea336567fcb1df51a1973";
  };
  driver = {
    revision = "8fb21420a704ea36aaf66df8288ed8ee9da2762d";
    configSize = 1282;
    configMagic = 283181258;
    configVersion = [1 7 0 316];
    # offsetof(struct cc33xx_conf_file, core.*) in the pinned packed conf.h.
    bleEnableOffset = 153;
    baudOffset = 156;
    flowControlOffset = 160;
    baudRate = 115200;
  };
  members = [
    {
      name = "cc33xx_2nd_loader.bin";
      size = 70916;
      sha256 = "d0974d018969cdc60572e64601f84314f1a30eab6ef1d4765a71aa5ceab017e2";
    }
    {
      name = "cc33xx_fw.bin";
      size = 539500;
      sha256 = "50d0b1b719c8e9b652dbcbe472204f2ef4325954b8fa8f314cab243fdc345f77";
    }
    {
      name = "cc33xx-conf.bin";
      size = 1282;
      sha256 = "20c34d04168fa145907a227f102fe9609fa2053b3c1a53552699d638dfd7227d";
    }
  ];
}
