"""Validate the declared model/compiled artifact/calibration binding before TI init."""
import hashlib
import json
import re
from pathlib import Path


def validate(model, artifacts):
    model, artifacts = Path(model), Path(artifacts)
    contract = json.loads((artifacts / "runtime-contract.json").read_text())
    if contract.get("schema") != 1 or contract.get("soc") != "j722s" or contract.get("compiler_version") != "11.02.16.00":
        raise ValueError("Unsupported model contract; require J722S TI 11.02.16.00")
    digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    if digest(model) != contract["model_sha256"]:
        raise ValueError("Model differs from the compiled artifact contract")
    members = contract["artifact_sha256"]
    required = {"calibration-manifest.json", "tidl-compiler-info.json", "allowedNode.txt", "onnxrtMetaData.txt"}
    networks = {match[1] for name in members if (match := re.fullmatch(r"(subgraph_[0-9]+)_tidl_net\.bin", name))}
    descriptors = {match[1] for name in members if (match := re.fullmatch(r"(subgraph_[0-9]+)_tidl_io_[0-9]+\.bin", name))}
    if not required <= members.keys() or not networks or networks != descriptors:
        raise ValueError("Incomplete artifact/calibration contract")
    if {path.name for path in artifacts.iterdir()} != set(members) | {"runtime-contract.json"}:
        raise ValueError("Artifact directory contains missing or undeclared members")
    for name, expected in members.items():
        if Path(name).name != name or digest(artifacts / name) != expected:
            raise ValueError(f"Artifact differs from the compiled contract: {name}")
    profile = contract["input"]
    if profile.get("layout") != "NCHW" or profile.get("color") != "RGB":
        raise ValueError("Reference runner requires NCHW RGB input")
    shape = profile.get("shape", [])
    if profile.get("dtype") not in ("uint8", "float32") or len(shape) != 4 or shape[:2] != [1, 3] or not all(isinstance(value, int) and value > 0 for value in shape):
        raise ValueError("Invalid fixed RGB input profile")
    mode = profile.get("preprocessing", {}).get("mode")
    if (profile["dtype"] == "uint8" and mode != "embedded") or (profile["dtype"] == "float32" and mode != "mean_scale"):
        raise ValueError("Preprocessing mode differs from the input dtype")
    return profile
