let
  main = {
    path = "/bus@f0000/r5fss@78400000/r5f@78400000";
    firmware = "j722s-main-r5f0_0-fw";
  };
  c7x0 = {
    path = "/bus@f0000/dsp@7e000000";
    firmware = "j722s-c71_0-fw";
  };
  c7x1 = {
    path = "/bus@f0000/dsp@7e200000";
    firmware = "j722s-c71_1-fw";
  };
in {
  ipc = {
    mcu-r5 = {
      path = "/bus@f0000/bus@4000000/r5fss@79000000/r5f@79000000";
      firmware = "j722s-mcu-r5f0_0-fw";
      regions = [["0xa1000000" "0x100000"] ["0xa1100000" "0xf00000"]];
    };
    main-r5 = main // {regions = [["0xa2000000" "0x100000"] ["0xa2100000" "0xf00000"]];};
    c7x0 = c7x0 // {regions = [["0xa3000000" "0x100000"] ["0xa3100000" "0xf00000"]];};
    c7x1 = c7x1 // {regions = [["0xa4000000" "0x100000"] ["0xa4100000" "0xf00000"]];};
  };
  vision = {
    main-r5 = main // {regions = [["0xa2000000" "0x100000"] ["0xa2100000" "0x1f00000"]];};
    c7x0 = c7x0 // {regions = [["0xad000000" "0x100000"] ["0xad100000" "0x3f00000"]];};
    c7x1 = c7x1 // {regions = [["0xb1000000" "0x100000"] ["0xb1100000" "0x3f00000"]];};
  };
}
