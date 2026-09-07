"""Record the exact deterministic synthetic calibration tensor stream."""
import hashlib
import json
import pathlib
import sys
import numpy as np

assert np.__version__ == "1.26.4"
rng = np.random.default_rng(722)
frames = [hashlib.sha256(rng.integers(0, 256, size=(1, 3, 224, 224), dtype=np.uint8).tobytes()).hexdigest() for _ in range(12)]
manifest = {"numpy_version": np.__version__, "rng": "numpy.default_rng(seed=722)", "shape": [1, 3, 224, 224], "dtype": "uint8", "frame_sha256": frames, "purpose": "synthetic integration calibration; not an accuracy benchmark"}
pathlib.Path(sys.argv[1]).write_text(json.dumps(manifest, sort_keys=True, indent=2) + "\n")
