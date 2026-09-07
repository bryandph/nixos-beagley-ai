"""Preserve TIDL public source notices and headers outside build outputs."""

import pathlib
import re
import shutil
import sys

out, dev = map(pathlib.Path, sys.argv[1:])
for path in pathlib.Path(".").rglob("*"):
    if not path.is_file() or "out" in path.parts:
        continue
    if path.suffix in (".h", ".hpp"):
        target = dev / "include/ti-tidl" / path
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
    if path.suffix in (".c", ".cpp", ".h", ".hpp"):
        leading = re.match(r"\s*(/\*.*?\*/)", path.read_text(errors="replace"), re.S)
        if leading and any(word in leading[1].lower() for word in ("copyright", "license", "spdx")):
            target = out / "share/licenses/beagley-ai-tidl/source-notices" / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(leading[1] + "\n")
