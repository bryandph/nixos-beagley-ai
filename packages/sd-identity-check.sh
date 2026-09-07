#!/usr/bin/env bash
set -eu
# shellcheck disable=SC1090
. "$1"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/class/block"
for disk in mmcblk4 mmcblk5 nvme0n1; do
  mkdir -p "$fixture/devices/block/$disk/device"
  echo SD >"$fixture/devices/block/$disk/device/type"
  ln -s "$fixture/devices/block/$disk" "$fixture/class/block/$disk"
  for number in 1 2; do
    mkdir -p "$fixture/devices/block/$disk/${disk}p$number"
    echo "$number" >"$fixture/devices/block/$disk/${disk}p$number/partition"
    ln -s "$fixture/devices/block/$disk/${disk}p$number" "$fixture/class/block/${disk}p$number"
  done
done
readlink() {
  case "$2" in
  /dev/*) echo "$2" ;;
  *) command readlink "$@" ;;
  esac
}
blkid() {
  case "$*" in
  '-c /dev/null -o device -t LABEL=BEAGLEY_ROOT')
    case "$scenario" in
    missing) return 2 ;;
    duplicate) printf '/dev/mmcblk4p2\n/dev/nvme0n1p2\n' ;;
    nvme) echo /dev/nvme0n1p2 ;;
    *) echo /dev/mmcblk4p2 ;;
    esac
    ;;
  '-c /dev/null -o device -t LABEL=BEAGLEYBOOT')
    if [ "$scenario" = different_disk ]; then echo /dev/mmcblk5p1; else echo /dev/mmcblk4p1; fi
    ;;
  '-p -s TYPE -o value /dev/mmcblk4p2')
    if [ "$scenario" = wrong_type ]; then echo xfs; else echo ext4; fi
    ;;
  '-p -s TYPE -o value /dev/mmcblk4p1') echo vfat ;;
  *) return 2 ;;
  esac
}
scenario=valid
beagley_check_sd_identity "$fixture"
for scenario in missing duplicate nvme different_disk wrong_type; do
  if beagley_check_sd_identity "$fixture"; then
    echo "guard incorrectly accepted $scenario" >&2
    exit 1
  fi
done
scenario=valid
echo MMC >"$fixture/devices/block/mmcblk4/device/type"
if beagley_check_sd_identity "$fixture"; then
  echo 'guard incorrectly accepted eMMC' >&2
  exit 1
fi
echo 'SD identity guard accepts one SD pair and rejects ambiguous, wrong-media and wrong-filesystem cases'
