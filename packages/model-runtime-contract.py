"""Bind the packaged RegNet input, compiler, calibration and runtime artifacts."""
import hashlib
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
model = root / "model/regnetx-200mf.onnx"
artifacts = root / "artifacts"
digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
info = json.loads((artifacts / "tidl-compiler-info.json").read_text())
calibration = json.loads((artifacts / "calibration-manifest.json").read_text())
assert info["model_sha256"] == digest(model)
assert info["compiler_version"] == "11.02.16.00"
assert "SOC=j722s" in "\n".join(info["tidl_tools_version"])
assert calibration["shape"] == [1, 3, 224, 224] and calibration["dtype"] == "uint8"
assert calibration["numpy_version"] == "1.26.4"
assert info["calibration_rng"] == calibration["rng"]
assert info["calibration_frames"] == len(calibration["frame_sha256"]) == 12
for name, expected in info["artifact_sha256"].items():
    assert digest(artifacts / name) == expected
contract = {
    "schema": 1, "soc": "j722s", "compiler_version": "11.02.16.00",
    "model_sha256": digest(model),
    "input": {"dtype": "uint8", "shape": [1, 3, 224, 224], "layout": "NCHW", "color": "RGB", "preprocessing": {"mode": "embedded"}},
    "artifact_sha256": {path.name: digest(path) for path in sorted(artifacts.iterdir()) if path.is_file() and path.name != "runtime-contract.json"},
}
(artifacts / "runtime-contract.json").write_text(json.dumps(contract, sort_keys=True, indent=2) + "\n")
