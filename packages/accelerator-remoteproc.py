"""Operate only the current profile's application cores after checking live DT ABI."""
import fcntl
import json
import pathlib
import struct
import sys
import time

DT = pathlib.Path("/sys/firmware/devicetree/base")
REMOTE = pathlib.Path("/sys/class/remoteproc")


def cells(path):
    data = path.read_bytes()
    if len(data) % 4:
        raise RuntimeError(f"Malformed DT cells: {path}")
    return struct.unpack(f">{len(data) // 4}I", data)


def identify(expected):
    if "78000000" in expected["path"]:
        raise RuntimeError("Device Manager is never an application target")
    node = DT / expected["path"].lstrip("/")
    matches = [r for r in REMOTE.glob("remoteproc*")
               if (r / "device/of_node").resolve() == node.resolve()]
    if len(matches) != 1:
        raise RuntimeError(f"Expected exactly one application core: {expected['path']}")
    regions = {}
    for reserved in (DT / "reserved-memory").iterdir():
        if (reserved / "phandle").exists():
            regions[cells(reserved / "phandle")[0]] = reserved
    observed = []
    for phandle in cells(node / "memory-region"):
        region = regions[phandle]
        if (region / "status").exists() and (region / "status").read_bytes().rstrip(b"\0") not in (b"okay", b"ok"):
            raise RuntimeError(f"Application reservation is disabled: {region}")
        if not (region / "no-map").exists():
            raise RuntimeError(f"Application reservation is mapped by Linux: {region}")
        a, b, c, d = cells(region / "reg")
        observed.append([(a << 32) | b, (c << 32) | d])
    wanted = [[int(v, 0) for v in pair] for pair in expected["regions"]]
    if observed != wanted:
        raise RuntimeError(f"Live DT ABI mismatch for {expected['path']}: reboot into the matching profile")
    return matches[0]


def validate_memory(expected):
    for name, region in expected.items():
        node = DT / "reserved-memory" / name
        if (node / "status").exists() and (node / "status").read_bytes().rstrip(b"\0") not in (b"okay", b"ok"):
            raise RuntimeError(f"Shared-memory reservation is disabled: {name}")
        if list(cells(node / "reg")) != [int(v, 0) for v in region["reg"]]:
            raise RuntimeError(f"Shared-memory ABI mismatch: {name}")
        if (node / "no-map").exists() != region.get("noMap", True):
            raise RuntimeError(f"Shared-memory mapping mismatch: {name}")
        compatible = (node / "compatible").read_bytes().split(b"\0")
        if region.get("compatible", "shared-dma-pool").encode() not in compatible:
            raise RuntimeError(f"Shared-memory allocator mismatch: {name}")
        if region.get("cma", False) and not all((node / flag).exists() for flag in ("reusable", "linux,cma-default")):
            raise RuntimeError("CMA ownership mismatch")


def preflight(remote, expected):
    state = (remote / "state").read_text().strip()
    firmware = (remote / "firmware").read_text().strip()
    if state not in ("offline", "running"):
        raise RuntimeError(f"Refusing transition from {state}: {expected['path']}")
    if state == "running" and firmware != expected["firmware"]:
        raise RuntimeError("Running application firmware has a different owner")


def transition(remote, expected, command):
    state = (remote / "state").read_text().strip()
    firmware = (remote / "firmware").read_text().strip()
    if command == "status":
        print(expected["path"], state, firmware)
        return
    preflight(remote, expected)
    desired = "running" if command == "start" else "offline"
    if state == desired:
        return
    if command == "start":
        (remote / "firmware").write_text(expected["firmware"])
    (remote / "state").write_text(command)
    for _ in range(100):
        if (remote / "state").read_text().strip() == desired:
            return
        time.sleep(0.1)
    raise RuntimeError(f"Application core did not reach {desired}: {expected['path']}")


def main():
    profile = json.loads(pathlib.Path(sys.argv[1]).read_text())
    contract = profile["cores"]
    if len(sys.argv) not in (3, 4) or sys.argv[2] not in ("status", "start", "stop"):
        raise RuntimeError("usage: beagley-ai-remoteproc {status|start|stop} [core]")
    command = sys.argv[2]
    if command == "stop" and not profile.get("allowStop", False):
        raise RuntimeError("This vision firmware does not acknowledge shutdown; restart the board instead")
    names = [sys.argv[3]] if len(sys.argv) == 4 else list(contract)
    if not all(name in contract for name in names):
        raise RuntimeError("Unknown application core; arbitrary sysfs paths are not accepted")
    if command == "stop":
        names.reverse()
    lock = None
    if command != "status":
        lock = open("/run/lock/beagley-ai-remoteproc.lock", "w")
        fcntl.flock(lock, fcntl.LOCK_EX)
    # Validate every selected core before the first state change.
    validate_memory(profile["memory"])
    selected = [(identify(contract[name]), contract[name]) for name in names]
    if command != "status":
        for remote, expected in selected:
            preflight(remote, expected)
    for remote, expected in selected:
        transition(remote, expected, command)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, KeyError, ValueError) as error:
        sys.exit(str(error))
