# J722S accelerator runtime

`nixosModules.beagley-ai-accelerator-runtime` provides the MPU OpenVX runtime,
TIDL libraries and the TI Python OSRT environment. Compose it with the matching
application firmware and 4 GB EdgeAI device tree. It does not replace or stop
the system Device Manager.

The runtime sources are pinned in `packages/accelerator-runtime-sources.json`
and `packages/accelerator-tidl-sources.json`; the RTOS SDK and board memory-map
patches are pinned in `packages/accelerator-release.nix`. The generated MPU
memory header and reserved-memory DTS must match the application firmware
byte-for-byte. `checks.<system>.accelerator-memory-map` enforces that contract.
The runtime and firmware builds disable Ethernet firmware ownership so Linux
retains CPSW Ethernet.

The source build installs `libtivision_apps.so.11.2.0` using its upstream SONAME,
RPMsg support, public SDK headers and diagnostic/conformance programs. TIDL adds
`libvx_tidl_rt.so`, `libtidl_tfl_delegate.so`, `libtidl_onnxrt_EP.so` and
`libtidlrt_EP.so`. The libraries use the matched PVR Mesa GBM implementation.
Build maps and intermediate objects are excluded from the runtime output.

## Python ABI

The OSRT wheel manifest pins TI's aarch64 CPython 3.12 payloads from TIDL tools
`11_02_16_00`: TFLite Runtime 2.12, ONNX Runtime TIDL 1.23, TVM 0.18 and
tidlruntime 0.1. The environment uses NumPy 1.26.4 because these wheels require
the NumPy 1 ABI. Source dependencies are built for that ABI. The vendor wheels
are unpacked without patching, stripping or bytecode rewriting, and an install
check compares every wheel member with the original archive.

Use the explicit environment instead of the host's general-purpose Python:

```sh
beagley-ai-osrt-check
beagley-ai-osrt-python application.py
```

The ABI check imports all four runtimes and reports ONNX provider availability.
Run it on a normal Linux host: ONNX CPU discovery needs `/sys`, which is absent
from the Nix build sandbox. Successful imports establish ABI compatibility;
they do not establish inference offload. Offload acceptance also requires
running application R5/C7x firmware, a model compiled for J722S using the matched
TIDL tools, correct output compared with a CPU reference, and evidence that the
TIDL provider executed the graph.

For OpenVX diagnostics, inspect the application remote processors and RPMsg
devices first. Never stop the system DM core. Run conformance programs only
after the matching application firmware and reserved-memory profile are active.

`sudo timeout 30 vx_app_heap_stats` initializes the common runtime, queries
enabled processors' heap/OS statistics, and deinitializes. Confirm the expected
C7x rows and exit status; `-v` also queries task stacks. This is a smaller first
diagnostic than the load or conformance programs.

On the enrolled board, both the four-runtime ABI check and this heap diagnostic
completed successfully. The vision DMA heap, IPC and remote services initialized;
MCU2_0, C7x_1 and C7x_2 returned memory statistics, including the expected 64 MiB
C7x heaps, and the runtime deinitialized cleanly. This establishes working
runtime/firmware communication; model offload is checked separately below.

The BSP patches a J722S SDK error path that overwrote IPC initialization failure
with later successful service initialization. Failed IPC now unwinds resources,
preserves the failure and does not increment the initialization reference count
or enter OpenVX initialization. Partial cleanup skips missing endpoints and an
RX thread that was never created. The package compiles and runs the patched
upstream functions with failure/retry mocks as a build regression check.

For the packaged ONR-CL-6360 RegNet model, run:

```sh
sudo timeout 180 beagley-ai-tidl-check \
  --model-root /run/current-system/sw/share/beagley-ai/models/ONR-CL-6360-regNetx-200mf \
  --report-dir /tmp/beagley-tidl-acceptance
```

Before inference, the checker verifies the model, artifact and calibration hashes
against `artifacts/runtime-contract.json`, including its J722S compiler and input
profile. The checker launches separate processes for `core_number=1` and `2`. The pinned
TI runtime maps these to DSP_C7_1 and DSP_C7_2 for J722S's default inference
mode. Each process compares deterministic uint8 input against CPU execution,
requires positive TIDL subgraph timing intervals and TIDL events in the ONNX
profile, and writes hashes and numerical comparisons. The default bounds are
cosine similarity at least 0.99 and relative L2 error at most 0.1; the report
records the selected bounds. This validates execution/output consistency, not
classification accuracy against a labeled dataset. It requires the matching
compiled model artifact and the active vision firmware profile.

## Licensing and source authority

The SDK manifest includes component copyright and full license texts. Packages
preserve it along with component manifests, source notices, public headers and
the ONNX/TensorFlow/protobuf notices used by TIDL. TI source licenses restrict
use to TI devices; proprietary vendor binary payloads remain unchanged.

- [TI reference builder and pinned versions](https://github.com/TexasInstruments-Sandbox/ti-edgeai-armbian-build/tree/be3a57d2760691f6b4f5cc7cae6e00ccddef7016)
- [TI vision-apps source](https://git.ti.com/cgit/processor-sdk/vision_apps/)
- [TI ARM TIDL source](https://git.ti.com/cgit/processor-sdk-vision/arm-tidl/)
- [TI RPMsg userspace source](https://git.ti.com/cgit/rpmsg/ti-rpmsg-char/)

See the hardware matrix for current physical acceptance results.
