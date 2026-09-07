# Offline accelerator firmware

`packages/accelerator-release.nix` pins the TI J722S RTOS SDK, three host
tool installers, the security-development helper source and the BeagleY-AI
reference patches. The x86_64-linux outputs are
`beagley-ai-accelerator-{armllvm,c7000,sysconfig,firmware}`. Build firmware with
`nix build .#packages.x86_64-linux.beagley-ai-accelerator-firmware` using an
x86 Linux builder.

The SDK setup script is never run: it downloads mutable dependencies. Nix
fetches the individually hashed inputs, installs ARM LLVM 4.0.4.LTS,
C7000 5.0.0.LTS and SysConfig 1.26.2.4477, then runs the SDK's offline version
generation, scrub and firmware targets. SysConfig uses its standalone Node
CLI; the original GUI payload is retained but is not used by the build. The tool packages retain TI's
license manifests. The installer runs through the Nix dynamic loader; its
installed payload remains byte-for-byte unchanged under `lib/original`, with
a SHA-256 inventory. A separate directory view supplies loader wrappers for
executables. Clang receives explicit resource and bundled subprocess paths,
so loader-based execution still finds its headers and linker. This respects the ARM Clang manifest’s requirement that TI binary
components remain unmodified. All three tool outputs remain conservatively
nonredistributable pending complete component redistribution review.

The firmware recipe disables Linux/QNX MPU builds and Ethernet firmware.
The reference CPSW patch removes RTOS Ethernet ownership. The memory-map
patch places the shared heap at physical `0x8a0000000`, size `0x20000000`,
within this board's upper DDR bank. Generated headers and the matching DT
memory fragment are installed alongside the firmware; the host runtime and
final DT must use the same map before these images are started.

`HS=0` disables the SDK staging target's secure-image signing step. Only
the unsigned Vision Apps application main R5 and two C7x ELF images are exported,
with explicit Linux remoteproc aliases. System device-manager firmware is
never exported or replaced. Vision Apps' `mcu2_0` naming must not be inferred
to identify the same core as similarly named files in TI's separate IPC-test
firmware release. Resource tables and load addresses determine compatibility.
The audited entry points and resource-table addresses are recorded in
`accelerator-release.nix` under `abi.applicationCores`; the R5 entry at zero
uses its local TCM vector mapping.

The local SDK patch honors `BUILD_LINUX_MPU=no` for TIDL's ARM target and
propagates DSP sub-build failures. Upstream invokes both through a semicolon,
which otherwise hides the irrelevant ARM target's empty-combination error.

The output preserves SDK license notices and ELF checksums. TI's SDK contains
multiple component licenses, including TI device-restricted binary libraries;
the assembled output remains conservatively nonredistributable pending a
complete linked-component redistribution review. A successful offline build
does not establish remoteproc, IPC, accelerator execution or workload
acceptance on the board.

## Sources

- [TI J722S RTOS SDK](https://www.ti.com/tool/PROCESSOR-SDK-J722S) and the
  archive's `psdk_rtos/PROCESSOR_SDK_RTOS_J722S_manifest.html`.
- [Pinned BeagleY-AI reference firmware builder](https://github.com/TexasInstruments-Sandbox/ti-edgeai-armbian-build/blob/be3a57d2760691f6b4f5cc7cae6e00ccddef7016/scripts/build-edgeai-firmware.sh)
  and [board firmware patches](https://github.com/TexasInstruments-Sandbox/ti-edgeai-armbian-build/tree/be3a57d2760691f6b4f5cc7cae6e00ccddef7016/patches/firmware).
