{
  runCommand,
  python3,
  binutils,
  firmware,
}: let
  abi = (import ./accelerator-release.nix).abi;
in
  runCommand "beagley-ai-accelerator-firmware-contract" {
    nativeBuildInputs = [python3 binutils];
    passAsFile = ["contract"];
    contract = builtins.toJSON abi;
  } ''
    python3 - "$contractPath" ${firmware} <<'PY'
    import json, pathlib, re, subprocess, sys
    abi = json.loads(pathlib.Path(sys.argv[1]).read_text())
    root = pathlib.Path(sys.argv[2]) / "lib/firmware"
    dtsi = (pathlib.Path(sys.argv[2]) / "share/beagley-ai/k3-j722s-rtos-memory-map.dtsi").read_text()
    for core, expected in abi["applicationCores"].items():
        region = re.search(re.escape(expected["memoryRegion"]) + r":\s+[^\{]+\{([^}]+)\}", dtsi).group(1)
        cells = [int(cell, 16) for cell in re.search(r"reg = <([^>]+)>", region).group(1).split()]
        region_start = (cells[0] << 32) | cells[1]
        region_end = region_start + (cells[2] << 32) + cells[3]
        elf = root / "beagley-ai" / f"vx_app_rtos_linux_{core}.out"
        assert (root / expected["alias"]).resolve() == elf.resolve()
        header = subprocess.check_output(["readelf", "-h", str(elf)], text=True)
        entry = re.search(r"Entry point address:\s+(0x[0-9a-f]+)", header).group(1)
        assert int(entry, 16) == int(expected["entry"], 16), (core, entry)
        sections = subprocess.check_output(["readelf", "-SW", str(elf)], text=True)
        address = re.search(r"\.resource_table\s+PROGBITS\s+([0-9a-f]+)", sections).group(1)
        assert int(address, 16) == int(expected["resourceTable"], 16), (core, address)
        program = subprocess.check_output(["readelf", "-lW", str(elf)], text=True)
        for line in program.splitlines():
            fields = line.split()
            if not fields or fields[0] != "LOAD":
                continue
            start, size = int(fields[3], 16), int(fields[5], 16)
            assert 0 <= int(fields[4], 16) <= size
            # Each core may load only its own generated reservation or R5 TCM.
            assert (core == "mcu2_0" and start + size <= 0x10000) or (
                region_start <= start and start + size <= region_end
            ), (core, hex(start), hex(size))
    assert not any("dm" in path.name for path in root.iterdir())
    PY
    touch "$out"
  ''
