"""Ensure installation preserves every supplied wheel member byte-for-byte."""

import pathlib
import sys
import zipfile

destination = pathlib.Path(sys.argv[1])
for archive in sys.argv[2:]:
    with zipfile.ZipFile(archive) as wheel:
        for member in wheel.infolist():
            if member.is_dir():
                continue
            actual = (destination / member.filename).read_bytes()
            if actual != wheel.read(member):
                raise SystemExit(f"Wheel member changed: {member.filename}")
print("All vendor wheel payloads are unchanged")
