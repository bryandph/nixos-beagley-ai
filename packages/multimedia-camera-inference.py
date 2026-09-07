"""Explicit IMX219 RAW10 -> TI ISP -> RGB -> ONNX/TIDL reference pipeline."""
import argparse
import json
import os
from pathlib import Path
import select
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--video", required=True, help="Configured CSI capture /dev/videoN")
    parser.add_argument("--sensor", required=True, help="Matching IMX219 /dev/v4l-subdevN")
    parser.add_argument("--mode", required=True, choices=["320x240", "640x480", "1280x720", "1640x1232", "1920x1080"])
    parser.add_argument("--bayer", choices=["rggb10", "bggr10", "gbrg10", "grbg10"], required=True)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--artifacts", type=Path, required=True, help="Matching TI-compiled model artifacts directory")
    parser.add_argument("--mean", type=float, nargs=3, metavar=("R", "G", "B"))
    parser.add_argument("--scale", type=float, nargs=3, metavar=("R", "G", "B"), help="RGB input = (pixel - mean) * scale")
    parser.add_argument("--frames", type=int, default=30)
    parser.add_argument("--timeout", type=float, default=30)
    args = parser.parse_args()
    if args.frames < 1 or args.timeout <= 0:
        parser.error("frames and timeout must be positive")
    for device in (args.video, args.sensor):
        if not Path(device).is_char_device():
            parser.error(f"Not a character device: {device}")
    if not args.model.is_file() or not args.artifacts.is_dir():
        parser.error("model file and compiled artifacts directory must exist")

    import numpy as np
    import onnxruntime as ort
    if "TIDLExecutionProvider" not in ort.get_available_providers():
        raise RuntimeError("TI execution provider is unavailable")
    from beagley_model_contract import validate
    profile = validate(args.model, args.artifacts)
    dtype = profile["dtype"]
    if dtype == "uint8":
        if profile["preprocessing"] != {"mode": "embedded"} or args.mean is not None or args.scale is not None:
            raise ValueError("uint8 model requires embedded normalization; omit --mean/--scale")
    elif profile["preprocessing"] != {"mode": "mean_scale", "mean": args.mean, "scale": args.scale} or args.mean is None or args.scale is None:
        raise ValueError("--mean/--scale must match the compiled float32 preprocessing contract")
    session = ort.InferenceSession(str(args.model), providers=[("TIDLExecutionProvider", {
        "artifacts_folder": str(args.artifacts.resolve()), "tidl_tools_path": "",
    }), "CPUExecutionProvider"])
    inputs = session.get_inputs()
    if len(inputs) != 1 or inputs[0].type not in ("tensor(float)", "tensor(uint8)"):
        raise ValueError("Reference pipeline requires one float32 or uint8 NCHW RGB input")
    actual_dtype = "uint8" if inputs[0].type == "tensor(uint8)" else "float32"
    if profile["dtype"] != actual_dtype or profile["shape"] != inputs[0].shape:
        raise ValueError("ONNX input differs from the compiled model contract")
    shape = inputs[0].shape
    if len(shape) != 4 or shape[:2] != [1, 3] or not all(isinstance(x, int) and x > 0 for x in shape):
        raise ValueError(f"Expected fixed [1, 3, height, width], got {shape}")
    height, width = shape[2:]
    if width % 4:
        raise ValueError("RGB output width must be divisible by four (GStreamer row alignment)")
    capture_width, capture_height = map(int, args.mode.split("x"))
    dcc = Path(os.environ["BEAGLEY_AI_IMX219_DCC"])
    members = json.loads((dcc / "modes.json").read_text())[args.mode]
    read_fd, write_fd = os.pipe()
    pipeline = [
        "beagley-ai-gst-launch", "-q", "v4l2src", f"device={args.video}", "io-mode=5", f"num-buffers={args.frames}",
        "!", f"video/x-bayer,width={capture_width},height={capture_height},format={args.bayer}le",
        "!", "tiovxisp", "sensor-name=SENSOR_SONY_IMX219_RPI", "format-msb=9",
        f"dcc-isp-file={dcc / members['viss']['file']}", f"sink_0::dcc-2a-file={dcc / members['2a']['file']}",
        f"sink_0::device={args.sensor}", "!", "video/x-raw,format=NV12",
        "!", "videoconvert", "!", "videoscale", "!", f"video/x-raw,format=RGB,width={width},height={height}",
        "!", "filesink", f"location=/proc/self/fd/{write_fd}", "sync=false",
    ]
    process = subprocess.Popen(pipeline, pass_fds=(write_fd,), stdout=sys.stderr)
    os.close(write_fd)
    frame_bytes = height * width * 3
    mean = np.array(args.mean, dtype=np.float32) if args.mean is not None else None
    scale = np.array(args.scale, dtype=np.float32) if args.scale is not None else None
    try:
        for frame in range(args.frames):
            payload = bytearray()
            while len(payload) < frame_bytes:
                ready, _, _ = select.select([read_fd], [], [], args.timeout)
                if not ready:
                    raise TimeoutError("Camera frame timed out; inspect media graph and remote processors")
                chunk = os.read(read_fd, frame_bytes - len(payload))
                if not chunk:
                    raise RuntimeError(f"Camera pipeline ended during frame {frame}")
                payload.extend(chunk)
            rgb = np.frombuffer(payload, dtype=np.uint8).reshape(height, width, 3)
            prepared = rgb if dtype == "uint8" else (rgb.astype(np.float32) - mean) * scale
            tensor = np.ascontiguousarray(prepared.transpose(2, 0, 1)[None])
            outputs = session.run(None, {inputs[0].name: tensor})
            if not all(np.isfinite(output).all() for output in outputs):
                raise RuntimeError("Inference produced nonfinite output")
            timing = session.get_TI_benchmark_data()
            intervals = {key.removesuffix("_proc_start"): int(timing.get(key.removesuffix("_start") + "_end", 0) - start)
                         for key, start in timing.items() if key.startswith("ts:subgraph_") and key.endswith("_proc_start")}
            if not intervals or any(value <= 0 for value in intervals.values()):
                raise RuntimeError("No positive TIDL subgraph execution interval")
            print(json.dumps({"frame": frame, "tidl_subgraph_intervals": intervals, "outputs": [{"shape": list(output.shape), "finite": bool(np.isfinite(output).all())} for output in outputs]}), flush=True)
        if process.wait(timeout=args.timeout):
            raise RuntimeError("GStreamer pipeline failed")
    finally:
        os.close(read_fd)
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


if __name__ == "__main__":
    main()
