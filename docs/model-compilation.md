# J722S model compilation

`packages.x86_64-linux.beagley-ai-model-tools` packages TI 11.02.16.00's x86
TIDL compiler and matching CPython 3.10 ONNX/TFLite wheels. Vendor executables
and libraries remain byte-for-byte intact under `lib/original`; adjacent
wrappers invoke Nix's ELF loader and library path. No foreign loader paths
are patched into vendor payloads.

The vendor ONNX extension requests an executable stack. The compiler wrapper
sets `GLIBC_TUNABLES=glibc.rtld.execstack=2` for that process, using
[glibc's documented compatibility setting](https://sourceware.org/glibc/manual/2.42/html_node/Dynamic-Linking-Tunables.html).
This permits the unchanged extension to load with modern glibc; it does not
change the builder's or board's global stack policy.

CPython 3.10.21 is built from its pinned official source. A scoped `python310`
attribute keeps Nixpkgs' build/host interpreter splices consistent. Scoped
TOML bootstrap dependencies restore Python 3.10 support in package recipes
that now assume Python 3.11 or later. This scope does not alter the consumer's
normal Python packages.

The environment explicitly uses NumPy 1.26.4, differing from the reference
Docker recipe's NumPy 1.23. The conversion uses twelve uint8 NCHW tensors,
shape 1×3×224×224, from `numpy.default_rng(seed=722)`. Their individual SHA-256
hashes and NumPy version are retained in `calibration-manifest.json`.
These synthetic inputs test reproducible integration, not classifier accuracy.

`packages.x86_64-linux.beagley-ai-regnet-model` extracts only ONNX source
model inputs from the pinned TI 11.02.00 AM67A RegNet 200mf archive. The archive's
previously compiled artifacts are never copied into the compiler workspace.
The pinned [TI reference compiler](https://github.com/TexasInstruments-Sandbox/ti-edgeai-armbian-build/blob/be3a57d2760691f6b4f5cc7cae6e00ccddef7016/scripts/compile-j722s-tidl-model.py)
is fetched by hash and run with its J722S compilation flags. Its acceptance
contract requires all 103 graph nodes in one subgraph, all four runtime
artifacts, exact input/output tensor signatures and a 380952-byte I/O descriptor.
The result is under `share/beagley-ai/models/ONR-CL-6360-regNetx-200mf`.
Importing `beagley-ai-regnet-model` retains it in the system generation and
links it at `/run/current-system/sw/share/beagley-ai/models/ONR-CL-6360-regNetx-200mf`.

```sh
nix build .#packages.x86_64-linux.beagley-ai-regnet-model
nix build .#checks.x86_64-linux.model-reproducibility
```

The second check compiles an independent derivation and compares the complete
runtime model tree, including compiler and calibration manifests. Passing
conversion and reproducibility checks does not prove board offload. Runtime
acceptance must select the matching vision profile, observe both C7x cores,
and compare TIDL output with CPU execution while Ethernet remains healthy.

Both conversions passed on separate builders and produced byte-identical
model trees: 103 offloaded nodes, a 380952-byte I/O descriptor and twelve
recorded calibration tensors. The 18.6 MiB output has no Nix store references,
so deploying it does not retain the x86 compiler environment. The vendor
archive is published under 11.02.16.00; its internal version marker reports
`REL.TIDL.11.02.16.01`, retained verbatim in the compiler manifest.

`artifacts/runtime-contract.json` binds the ONNX weights, compiled artifacts,
compiler metadata and calibration manifest by SHA-256. The runtime diagnostic
and camera runner validate it before loading the model. RegNet accepts uint8
RGB NCHW tensors with normalization embedded in the graph.

On the board, each C7x passed three RegNet runs with all 103 graph nodes
offloaded and three TIDL profiling events. Both cores produced identical outputs.
Against CPU execution, cosine similarity was 0.9978846 and relative L2 error
0.068401, satisfying the diagnostic thresholds of 0.99 and 0.1 respectively.
This accepts synthetic inference integration; it does not measure classifier
accuracy on a representative dataset.

`packages/model-release.nix` records every URL/hash and the reference revision.
The model archive and tools archive contain no standalone redistribution
license file. The reference repository also exposes no top-level LICENSE at
the pinned revision. Consequently both tools and model outputs retain a
conservative unfree classification; public availability is not treated as a
redistribution grant. Wheel notices remain in their extracted dist-info
metadata, original vendor files remain intact, and any model notice files are
retained. This package does not relicense TI binaries, downloaded model weights,
or the reference compiler script.
