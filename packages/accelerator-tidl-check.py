"""Compare TI RegNet inference against CPU execution separately on both C7x cores."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-root", type=Path, required=True)
    parser.add_argument("--report-dir", type=Path, required=True)
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--min-cosine", type=float, default=0.99)
    parser.add_argument("--max-relative-l2", type=float, default=0.1)
    parser.add_argument("--core", type=int, choices=[1, 2], help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.runs < 1 or not 0 < args.min_cosine <= 1 or args.max_relative_l2 <= 0:
        parser.error("Invalid run count or comparison tolerance")
    args.report_dir.mkdir(parents=True, exist_ok=True)
    if args.core is None:
        for core in (1, 2):
            subprocess.run([sys.executable, __file__, *sys.argv[1:], "--core", str(core)], check=True)
        reports = [json.loads((args.report_dir / f"c7x-{core}.json").read_text()) for core in (1, 2)]
        (args.report_dir / "both-c7x.json").write_text(json.dumps({"passed": True, "cores": reports}, indent=2) + "\n")
        print("Both C7x cores passed TIDL subgraph execution and CPU-reference comparison.")
        return

    import numpy as np
    import onnxruntime as ort
    model = args.model_root / "model/regnetx-200mf.onnx"
    artifacts = args.model_root / "artifacts"
    if not model.is_file() or not (artifacts / "subgraph_0_tidl_net.bin").is_file():
        parser.error("Expected the matched ONR-CL-6360 RegNet model and compiled artifacts")
    from beagley_model_contract import validate
    profile = validate(model, artifacts)
    if profile != {"dtype": "uint8", "shape": [1, 3, 224, 224], "layout": "NCHW", "color": "RGB", "preprocessing": {"mode": "embedded"}}:
        raise ValueError("Expected the packaged RegNet embedded-normalization input contract")
    if "TIDLExecutionProvider" not in ort.get_available_providers():
        raise RuntimeError("TIDL execution provider missing")
    cpu_options = ort.SessionOptions()
    cpu_options.intra_op_num_threads = 1
    cpu = ort.InferenceSession(str(model), sess_options=cpu_options, providers=["CPUExecutionProvider"])
    input_info = cpu.get_inputs()
    if len(input_info) != 1 or input_info[0].shape != [1, 3, 224, 224] or input_info[0].type != "tensor(uint8)":
        raise ValueError("Expected TI RegNet uint8 [1,3,224,224] input with embedded normalization")
    pixels = np.random.default_rng(722).integers(0, 256, (1, 3, 224, 224), dtype=np.uint8)
    feed = {input_info[0].name: pixels}
    reference = cpu.run(None, feed)
    del cpu
    options = ort.SessionOptions()
    options.enable_profiling = True
    options.profile_file_prefix = str(args.report_dir / f"c7x-{args.core}-profile")
    session = ort.InferenceSession(str(model), sess_options=options, providers=[("TIDLExecutionProvider", {
        "artifacts_folder": str(artifacts.resolve()), "core_number": str(args.core), "debug_level": "1",
    }), "CPUExecutionProvider"])
    runs = []
    for index in range(args.runs):
        actual = session.run(None, feed)
        timing = session.get_TI_benchmark_data()
        subgraphs = {}
        for key, start in timing.items():
            if key.startswith("ts:subgraph_") and key.endswith("_proc_start"):
                end = timing.get(key.removesuffix("_start") + "_end", 0)
                if end <= start:
                    raise AssertionError(f"C7x {args.core}: nonpositive TIDL execution interval")
                subgraphs[key.removesuffix("_proc_start")] = int(end - start)
        if not subgraphs:
            raise AssertionError("No executed TIDL subgraph; provider availability is insufficient")
        comparisons = []
        if len(actual) != len(reference):
            raise AssertionError("Output count differs from CPU execution")
        for result, expected in zip(actual, reference):
            if result.shape != expected.shape or not np.isfinite(result).all() or not np.isfinite(expected).all():
                raise AssertionError("Invalid output shape or nonfinite values")
            left, right = result.astype(np.float64).ravel(), expected.astype(np.float64).ravel()
            cosine = float(np.dot(left, right) / max(np.linalg.norm(left) * np.linalg.norm(right), 1e-30))
            relative_l2 = float(np.linalg.norm(left - right) / max(np.linalg.norm(right), 1e-30))
            if cosine < args.min_cosine or relative_l2 > args.max_relative_l2:
                raise AssertionError(f"CPU comparison failed: cosine={cosine}, relative_l2={relative_l2}")
            comparisons.append({"cosine": cosine, "relative_l2": relative_l2,
                "shape": list(result.shape), "sha256": hashlib.sha256(result.tobytes()).hexdigest()})
        runs.append({"run": index, "tidl_subgraph_intervals": subgraphs, "outputs": comparisons})
    profile = Path(session.end_profiling())
    events = json.loads(profile.read_text())
    tidl_events = [event for event in events if event.get("args", {}).get("provider") == "TIDLExecutionProvider"]
    if not tidl_events:
        raise AssertionError("ONNX profile contains no TIDL execution events")
    report = {"core_number": args.core, "model_sha256": hashlib.sha256(model.read_bytes()).hexdigest(),
        "input_sha256": hashlib.sha256(pixels.tobytes()).hexdigest(), "profile": str(profile),
        "tidl_profile_events": len(tidl_events), "runs": runs,
        "tolerances": {"min_cosine": args.min_cosine, "max_relative_l2": args.max_relative_l2}}
    (args.report_dir / f"c7x-{args.core}.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"C7x {args.core}: {len(runs)} verified TIDL runs", flush=True)


if __name__ == "__main__":
    main()
