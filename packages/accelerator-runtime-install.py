"""Install public SDK headers and preserve source copyright/license notices."""

import pathlib
import re
import shutil
import sys

out, dev = map(pathlib.Path, sys.argv[1:])
licenses = out / "share/licenses/beagley-ai-accelerator-runtime"
projects = ["sdk_builder", "app_utils", "vision_apps", "tiovx", "imaging", "video_io", "ti-perception-toolkit", "psdk_include"]
for project in projects:
    for path in pathlib.Path(project).rglob("*"):
        if not path.is_file() or "out" in path.parts:
            continue
        if path.suffix in (".h", ".hpp"):
            target = dev / "include/ti-edgeai" / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
        if any(word in path.name.lower() for word in ("license", "licence", "manifest", "copying")):
            target = licenses / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
        if path.suffix in (".c", ".cpp", ".h", ".hpp"):
            text = path.read_text(errors="replace")
            leading = re.match(r"\s*(/\*.*?\*/)", text, re.S)
            if leading and any(word in leading[1].lower() for word in ("copyright", "license", "spdx")):
                target = licenses / "source-notices" / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(leading[1] + "\n")
