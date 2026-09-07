"""Validate the composed boot DT, including overlays that can be silently skipped."""

import subprocess
import sys

dtb, maximum = sys.argv[1], int(sys.argv[2])


def get(node, prop, kind="s"):
    return subprocess.check_output(
        ["fdtget", "-t", kind, dtb, node, prop], text=True
    ).strip()


def cells(node, prop):
    return [int(value, 16) for value in get(node, prop, "x").split()]


def children(node):
    return subprocess.check_output(["fdtget", "-l", dtb, node], text=True).split()


def properties(node):
    return subprocess.check_output(["fdtget", "-p", dtb, node], text=True).split()


nodes = []


def walk(node):
    nodes.append(node)
    for child in children(node):
        walk(node.rstrip("/") + "/" + child)


walk("/")
phandles = {
    cells(node, "phandle")[0]: node
    for node in nodes
    if "phandle" in properties(node)
}
external = get("/aliases", "rtc0")
internal = get("/aliases", "rtc1")
assert external != internal
assert get(external, "compatible") == "dallas,ds1340", external
assert get(internal, "compatible") == "ti,am62-rtc", internal

cpus = ["/cpus/" + name for name in children("/cpus") if name.startswith("cpu@")]
assert len(cpus) == 4, cpus
tables = {cells(cpu, "operating-points-v2")[0] for cpu in cpus}
assert len(tables) == 1, tables
table = phandles[tables.pop()]
frequencies = []
for opp in children(table):
    node = table + "/" + opp
    words = cells(node, "opp-hz")
    assert len(words) == 2, words
    frequencies.append((words[0] << 32) | words[1])
    assert "opp-microvolt" not in properties(node), "unexpected voltage control"
assert len(set(frequencies)) >= 2, frequencies
assert min(frequencies) > 0 and max(frequencies) == maximum, frequencies
assert "opp-shared" in properties(table)
for cpu in cpus:
    assert cells(cpu, "#cooling-cells") == [2]

cpu_ids = {cells(cpu, "phandle")[0] for cpu in cpus}
maps = [node for node in nodes if "cooling-device" in properties(node)]
matched = 0
for node in maps:
    cooling = cells(node, "cooling-device")
    if cooling[0] not in cpu_ids:
        continue
    matched += 1
    assert len(cooling) == 3
    low, high = cooling[1:]
    assert low == 0xFFFFFFFF or low < len(frequencies)
    assert high == 0xFFFFFFFF or high < len(frequencies)
    assert low == 0xFFFFFFFF or high == 0xFFFFFFFF or low <= high
    trip = phandles[cells(node, "trip")[0]]
    assert get(trip, "type") == "passive"
    threshold = cells(trip, "temperature")[0]
    assert 0 < cells(trip, "hysteresis")[0] < threshold
    zone = node.split("/cooling-maps/")[0]
    criticals = [
        cells(zone + "/trips/" + name, "temperature")[0]
        for name in children(zone + "/trips")
        if get(zone + "/trips/" + name, "type") == "critical"
    ]
    assert criticals and threshold < min(criticals)
assert matched, "no CPU passive cooling map"
print("Composed RTC aliases, shared CPU OPP limits and thermal cooling contract passed")
