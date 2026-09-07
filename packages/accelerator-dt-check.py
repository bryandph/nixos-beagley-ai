"""Validate the composed accelerator DT against the board and generated SDK ABI."""

import json
import pathlib
import re
import subprocess
import sys


def check(dtb, contract, generated):
    def get(node, prop, kind="x"):
        return subprocess.check_output(
            ["fdtget", "-t", kind, dtb, node, prop], text=True
        ).split()

    def listing(node, flag):
        return subprocess.check_output(["fdtget", flag, dtb, node], text=True).split()

    def words(node, prop):
        return [int(v, 16) for v in get(node, prop)]

    def ranges(node):
        cells = words(node, "reg")
        assert len(cells) % 4 == 0, (node, "malformed reg")
        return [
            ((cells[i] << 32) | cells[i + 1], (cells[i + 2] << 32) | cells[i + 3])
            for i in range(0, len(cells), 4)
        ]

    def enabled(node):
        return "status" not in listing(node, "-p") or get(node, "status", "s") in (["okay"], ["ok"])

    ram = [
        region
        for node in listing("/", "-l")
        if node.startswith("memory@")
        for region in ranges("/" + node)
    ]
    assert sorted(ram) == [(0x80000000, 0x80000000), (0x880000000, 0x80000000)], ram
    reserved = {}
    phandles = {}
    dynamic = 0
    for name in listing("/reserved-memory", "-l"):
        node = "/reserved-memory/" + name
        if not enabled(node):
            continue
        props = listing(node, "-p")
        if "phandle" in props:
            phandles[words(node, "phandle")[0]] = node
        if "reg" in props:
            reserved[node] = ranges(node)
        elif "size" in props:
            size = words(node, "size")
            assert len(size) == 2
            dynamic += (size[0] << 32) | size[1]
    allocated = []
    for node, regions in reserved.items():
        for start, size in regions:
            assert size > 0 and any(base <= start and start + size <= base + length for base, length in ram), (node, "outside RAM")
            assert all(start + size <= base or start >= end for base, end, _ in allocated), (node, "reservation overlap", allocated)
            allocated.append((start, start + size, node))
    available = sum(size for _, size in ram) - sum(end - start for start, end, _ in allocated) - dynamic
    assert available >= 1024**3, ("less than 1 GiB remains after reservations/CMA", available)

    def core_regions(path):
        return [reserved[phandles[phandle]][0] for phandle in words(path, "memory-region")]

    dm = "/bus@f0000/bus@b00000/r5fss@78000000/r5f@78000000"
    assert core_regions(dm) == [(0xA0000000, 0x100000), (0xA0100000, 0xF00000)], "Device Manager reservations changed"
    assert enabled(dm) and enabled(dm.rsplit("/", 1)[0]), "Device Manager disabled"
    for phandle in words(dm, "memory-region"):
        assert "no-map" in listing(phandles[phandle], "-p"), "Device Manager memory mapped by Linux"
    mcu = "/bus@f0000/bus@4000000/r5fss@79000000/r5f@79000000"
    assert core_regions(mcu) == [(0xA1000000, 0x100000), (0xA1100000, 0xF00000)], "MCU R5 reservation changed"
    for name, core in contract["cores"].items():
        assert "78000000" not in core["path"], "DM selected as application core"
        assert enabled(core["path"]), (name, "disabled")
        assert core_regions(core["path"]) == [tuple(int(v, 0) for v in pair) for pair in core["regions"]], (name, "wrong core memory ABI")
        for phandle in words(core["path"], "memory-region"):
            assert "no-map" in listing(phandles[phandle], "-p"), (name, "mapped core reservation")

    if contract["profile"] == "vision":
        assert generated != "-", "vision check requires generated firmware memory map"
        source = pathlib.Path(generated).read_text()
        for name, expected in contract["memory"].items():
            node = "/reserved-memory/" + name
            assert enabled(node), (name, "disabled vision reservation")
            observed = words(node, "reg")
            assert observed == [int(v, 0) for v in expected["reg"]], (name, "metadata mismatch")
            props = listing(node, "-p")
            assert ("no-map" in props) == expected.get("noMap", True), (name, "mapping policy")
            if expected.get("cma", False):
                assert "reusable" in props and "linux,cma-default" in props
                assert get(node, "compatible", "s") == ["shared-dma-pool"]
            if "label" in expected:
                match = re.search(re.escape(expected["label"]) + r":\s+[^\{]+\{([^}]+)\}", source)
                assert match, (name, "missing generated SDK label")
                reg = re.search(r"reg\s*=\s*<([^>]+)>", match.group(1))
                assert reg and observed == [int(v, 16) for v in reg.group(1).split()], (name, "SDK ABI mismatch")
        assert dynamic == 0, "vision profile retained an uncontrolled dynamic reservation"
    print(f"Validated {contract['profile']} core associations, DM isolation, disjoint 4 GiB memory ABI; {available} bytes remain after CMA")


if __name__ == "__main__":
    check(sys.argv[1], json.loads(pathlib.Path(sys.argv[2]).read_text()), sys.argv[3])
