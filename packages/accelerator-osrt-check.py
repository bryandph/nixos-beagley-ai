"""Runtime ABI check; CPU discovery requires normal host /sys, outside a build."""

import importlib.metadata
import json
import sys

import numpy
import onnxruntime
import tflite_runtime.interpreter
import tidlruntime
import tvm

assert sys.version_info[:2] == (3, 12)
assert numpy.__version__.startswith("1.26.")
providers = onnxruntime.get_available_providers()
assert any("TIDL" in provider for provider in providers), providers
print(json.dumps({
    "python": sys.version.split()[0],
    "numpy": numpy.__version__,
    "onnxruntime": onnxruntime.__version__,
    "providers": providers,
    "tvm": tvm.__version__,
    "tflite_runtime": importlib.metadata.version("tflite-runtime"),
    "tidlruntime": importlib.metadata.version("tidlruntime"),
    "scope": "Imports and provider availability; inference offload requires a compiled model and running application firmware",
}, indent=2))
