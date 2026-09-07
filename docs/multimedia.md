# Multimedia and GPU

Import `nixosModules.beagley-ai-multimedia` for the Wave521C firmware and V4L2
tools. The provider kernel supplies Wave5 and E5010 drivers. E5010 needs no
separate firmware. The kernel includes TI's fix for the pinctrl wake interrupt
incorrectly claiming the JPEG encoder's SPI 98; see the source and patch hashes
in `packages/multimedia-release.nix`.

Discover functions by driver and V4L2 capabilities, rather than assuming a
particular `/dev/videoN` number:

```sh
v4l2-ctl --list-devices
v4l2-ctl --device /dev/videoN --all
v4l2-ctl --device /dev/videoN --list-formats-out
v4l2-ctl --device /dev/videoN --list-formats
```

Wave5 firmware is licensed for unmodified redistribution on TI silicon only.
The package preserves `LICENCE.cnm`. A device node alone is not proof of a
successful codec operation: encode a supported raw frame, validate the resulting
bitstream, then decode a supported generated stream and inspect the output.

## Rogue GPU tuple

Import `nixosModules.beagley-ai-gpu` alongside the core module to compose the
vendor kernel module, userspace, GPU firmware and TI-selected Mesa shims. The
release metadata pins all four components. The J722S kernel build directory is
an upstream symlink to AM62P, with BVNC `36.53.104.796`; both kernel and userspace
use DDK `25.2.6850647`. This is separate from the in-tree `img,img-axe` driver.

Vendor userspace is installed byte-for-byte, with its complete license. It is
neither stripped nor patched. Programs use an explicit Nix dynamic loader and
library search path. Run third-party graphics applications through the provided
environment wrapper so that the matched DRI, EGL, Vulkan WSI and OpenCL libraries
are found:

```sh
beagley-ai-gpu-run clinfo
beagley-ai-gpu-run vulkaninfo --summary
beagley-ai-gpu-run eglinfo -B
rgx_compute_test
```

The wrapper selects this provider for that process. Do not run GPU validation
under software-only Mesa and count a successful llvmpipe result as GPU support.
Check the kernel log, GPU device identity and reported renderer before recording
offload. A physical display is needed to validate HDMI modes and HDMI audio;
headless EGL/compute checks establish different capabilities.

The TI userspace tree provides PVR Mesa interfaces rather than a standalone EGL
implementation. The Mesa shim source is therefore part of the pinned tuple;
substituting ordinary Mesa does not provide this interface. The package builds
the PVR Gallium frontend, EGL/GBM and Vulkan WSI with Wayland support. X11/GLX is
not part of this profile.

## Camera and panel profiles

The following composable modules provide specific device trees, leaving the
server profile's connectors available until the relevant hardware is attached:

| Module | Hardware | Shared resources |
| --- | --- | --- |
| `beagley-ai-csi0-imx219` | Raspberry Pi Camera V2 IMX219 on CSI0 | MCU GPIO 15, I2C2 address 0x10 |
| `beagley-ai-csi1-imx219` | Raspberry Pi Camera V2 IMX219 on CSI1 | CSI1/DSI0 mux, GPIO0 1/2, GPIO1 24, I2C0 address 0x10 |
| `beagley-ai-dsi-rpi-7inch` | Original Raspberry Pi 7-inch DSI display | CSI1/DSI0 mux, GPIO0 1/2, I2C0 address 0x45, DSS1 VP2 |
| `beagley-ai-oldi-lcd185` | LincolnTech LCD185-101CTL1ARNTT with touch | OLDI, ECAP0 backlight, MCU GPIO 11, GPIO0 14, I2C1 addresses 0x57/0x5d, DSS0 VP1 |

CSI1 and DSI cannot be composed together: both require the same physical
connector and mux. CSI0 can coexist with either. OLDI owns ECAP0, so header PWM
profiles using that controller cannot coexist. Nix evaluation rejects conflicting
resource owners. The media-profile check compiles and applies dual-camera,
CSI0+DSI, and OLDI+DSI trees and verifies that CSI1+DSI is rejected.

These profiles adapt the pinned BeagleBoard wiring to the selected 6.12 kernel.
The RPi profile is for the original 7-inch display, not Touch Display 2 or a
generic Waveshare panel. Physical camera/display verification needs the named
fixture. Use `media-ctl --print-topology` and `v4l2-ctl --list-devices` to discover
the camera graph; raw Bayer capture does not establish VPAC/ISP or inference
offload.

## Sources

### Camera ISP and inference

Compose `beagley-ai-camera`, `beagley-ai-vision` and
`beagley-ai-accelerator-runtime` with either IMX219 connector profile, or add
the connector profile to `beagley-ai-full`. The camera tooling feature installs
`beagley-ai-gst-inspect`, `beagley-ai-gst-launch`, and
`beagley-ai-camera-inference`; it does not select a sensor connector or start
capture automatically.

`packages/multimedia-edgeai-sources.json` pins the four source components to
TI's meta-edgeai `04db1a86f468b1072eaf72cb723b0d1b76a505ce` recipes. The
GStreamer plugin links the same OpenVX runtime used by the vision firmware.
The ISP implementation contains J722S paths; the BSP extends its AM62A-only
build and registration gates to J722S, including the combined VISS/scaler
module. It builds the missing host 2A wrapper from the same imaging source
and links its algorithms from the matched MPU runtime. The separate C++ DL-inferer plugin is
disabled; inference uses the matched Python ONNX/TIDL runtime instead.

IMX219 tuning comes from the pinned imaging component, with unchanged bytes,
member sizes and SHA256 recorded in `packages/multimedia-imx219-dcc.json`.
The reference pipeline accepts RAW10 only and pairs VISS/2A tuning for
320×240, 640×480, 1280×720, 1640×1232, or 1920×1080. A different resolution
or bit depth requires its own reviewed tuning profile.

The selected GStreamer 1.26 `v4l2src` advertises unpacked RAW10 as `rggb10le`
(and equivalent names for the other Bayer orders). TI's plugin originally used
`rggb10`. The BSP adds the native little-endian names to the ISP caps and raw
container parsers while retaining TI's aliases. The runner's logical
`--bayer rggb10` selects `rggb10le` capture caps. A build regression inspects the
actual V4L2/ISP factory templates without opening hardware and verifies caps
intersection and matching container parsing for all four RAW10 orders.

The [reference Bayer patch](https://github.com/TexasInstruments-Sandbox/ti-edgeai-armbian-build/blob/be3a57d2760691f6b4f5cc7cae6e00ccddef7016/packages/edgeai/edgeai-gst-plugins/patches/0003-isp-accept-gstreamer-native-endian-bayer-caps.patch)
addresses Ubuntu GStreamer 1.24's eight-bit `rggble` names. GStreamer 1.26
advertises eight-bit `rggb` and higher-depth names with an explicit depth and
endianness, so that patch is not applied unchanged.

First inspect the media topology and configure the sensor, CSI receiver and
capture node to the same Bayer order, RAW10 depth and resolution. Discover
device numbers with `media-ctl --print-topology`; they are not stable aliases.
With the vision profile running, check `sudo beagley-ai-gst-inspect tiovxisp` before capture. Element inspection instantiates OpenVX and therefore requires the board DMA heap and `/dev/mem`; it is not a hardware-independent package check. Then use
`beagley-ai-camera-inference --help` and pass the discovered `--video` and
`--sensor`, matching `--mode` and `--bayer`, a model file and its compiled
`--artifacts` directory, and the model's three RGB `--mean` and `--scale`
values for a float32 model. For the packaged uint8 RegNet model, omit `--mean`
and `--scale`: normalization is embedded in the graph. Run with the privileges
needed for the vision runtime (`sudo` for initial validation). The runner requires
fixed float32 or uint8 NCHW RGB input. It processes float32 pixels as
`(pixel - mean) * scale` or preserves uint8 pixels for embedded normalization;
model input width must be divisible by four. `artifacts/runtime-contract.json`
binds the input profile, compiler release, model SHA256, compiled artifacts and
calibration manifest. The runner rejects mismatches; float32 preprocessing values
must match that declared contract.

The pipeline uses hardware ISP, then CPU RGB conversion/scaling and
preprocessing, then the TIDL execution provider (with CPU partitions allowed
by that provider). It rejects nonfinite outputs or missing/nonpositive TIDL
subgraph timing intervals, and prints frame counts, timing and output shapes.
Provider registration alone is not proof of DSP offload: confirm
remote-processor execution and compare output against the model's reference.
Camera/ISP/inference capture acceptance requires the physical IMX219 fixture;
source builds and plugin discovery do not substitute for that check.

On a clean vision-profile boot, ISP element inspection initialized and
deinitialized successfully. A previous failed remote-processor stop had left
RPMsg unusable despite the processor reporting `running`; that condition must
be recovered by rebooting. The runtime now preserves IPC initialization failure,
and inspection skips querying a NULL stream context during teardown.

### Accepted codec and GPU workloads

On the board, `rgx_compute_test -f16 -w8 -s32 -i1000` completed all 16 kicks.
Wave5 encoded ten 640×480 H.264 frames; hardware decoding produced ten frames
whose pixel MD5 values matched software decoding. Use FFmpeg
`-fps_mode passthrough` when comparing decoder outputs: timestamp-based frame
selection otherwise dropped nine frames in this test. E5010 encoded a
640×480 NV12 test pattern as a valid JPEG. See the hardware matrix for the
full acceptance record.

- [TI E5010 interrupt collision and fix](https://sir.ext.ti.com/jira/browse/EXT_EP-13139)
- [Pinned Rogue kernel source](https://github.com/TexasInstruments/ti-img-rogue-driver/tree/a838ac0074db640ebd1b64be6364417b1bbca3cd)
- [Pinned Rogue userspace and license](https://github.com/TexasInstruments/ti-img-rogue-umlibs/tree/adcbb5c620ff172da4152c02a2fee8f42dc4c472)
- [TI Mesa provider recipe](https://github.com/TexasInstruments/meta-ti/blob/7ff810824442c56ef59fa2d705d64a03ade5f5f7/meta-ti-bsp/recipes-graphics/mesa/mesa-pvr_24.0.1.bb)

Consult the hardware matrix for physical acceptance status. Package build and
ABI/source matching are distinct from a hardware workload passing.
