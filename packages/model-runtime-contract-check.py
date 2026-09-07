"""Regression: model, compiled artifacts and calibration cannot be mixed."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from beagley_model_contract import validate

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    (root / "model").mkdir()
    artifacts = root / "artifacts"
    artifacts.mkdir()
    model = root / "model/regnetx-200mf.onnx"
    model.write_bytes(b"test-model")
    members = ["allowedNode.txt", "onnxrtMetaData.txt", "subgraph_0_tidl_io_1.bin", "subgraph_0_tidl_net.bin"]
    for name in members:
        (artifacts / name).write_bytes(name.encode())
    digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    info = {"model_sha256": digest(model), "compiler_version": "11.02.16.00", "tidl_tools_version": ["SOC=j722s"],
            "calibration_rng": "numpy.default_rng(seed=722)", "calibration_frames": 12,
            "artifact_sha256": {name: digest(artifacts / name) for name in members}}
    calibration = {"shape": [1, 3, 224, 224], "dtype": "uint8", "numpy_version": "1.26.4",
                   "rng": info["calibration_rng"], "frame_sha256": ["fixture"] * 12}
    (artifacts / "tidl-compiler-info.json").write_text(json.dumps(info))
    (artifacts / "calibration-manifest.json").write_text(json.dumps(calibration))
    subprocess.run([sys.executable, sys.argv[1], str(root)], check=True)
    assert validate(model, artifacts)["preprocessing"] == {"mode": "embedded"}
    for path in [model, artifacts / "subgraph_0_tidl_net.bin", artifacts / "calibration-manifest.json"]:
        original = path.read_bytes()
        path.write_bytes(original + b"changed")
        try:
            validate(model, artifacts)
        except ValueError:
            pass
        else:
            raise AssertionError(f"Mixed model/calibration/artifact accepted: {path.name}")
        path.write_bytes(original)
    contract_path = artifacts / "runtime-contract.json"
    contract = json.loads(contract_path.read_text())
    extra = artifacts / "subgraph_99_tidl_io_1.bin"
    extra.write_bytes(b"stale descriptor")
    try:
        validate(model, artifacts)
    except ValueError:
        pass
    else:
        raise AssertionError("Undeclared stale artifact accepted")
    extra.unlink()
    incomplete = json.loads(contract_path.read_text())
    del incomplete["artifact_sha256"]["subgraph_0_tidl_io_1.bin"]
    descriptor = artifacts / "subgraph_0_tidl_io_1.bin"
    original_descriptor = descriptor.read_bytes()
    descriptor.unlink()
    contract_path.write_text(json.dumps(incomplete))
    try:
        validate(model, artifacts)
    except ValueError:
        pass
    else:
        raise AssertionError("Network without an I/O descriptor accepted")
    descriptor.write_bytes(original_descriptor)
    contract["soc"] = "am62a"
    contract_path.write_text(json.dumps(contract))
    try:
        validate(model, artifacts)
    except ValueError:
        pass
    else:
        raise AssertionError("Wrong SoC accepted")
print("Model/artifact/calibration contract regression passed")
