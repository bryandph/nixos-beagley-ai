{
  runCommand,
  lib,
  kernel,
  profile,
}:
runCommand "beagley-ai-${profile}-kernel-contract" {} ''
  for symbol in REMOTEPROC TI_K3_R5_REMOTEPROC TI_K3_DSP_REMOTEPROC RPMSG_CHAR RPMSG_CTRL RPMSG_VIRTIO OMAP2PLUS_MBOX; do
    grep -Eq "^CONFIG_$symbol=[ym]$" ${kernel.configfile}
  done
  ${lib.optionalString (profile == "vision") ''
    for symbol in DEVMEM DMABUF_HEAPS DMABUF_HEAPS_CMA DMABUF_HEAPS_CARVEOUT; do
      grep -qx "CONFIG_$symbol=y" ${kernel.configfile}
    done
  ''}
  touch "$out"
''
