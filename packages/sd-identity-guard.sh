# shellcheck shell=bash
# Sourced by the legacy initrd after device discovery and before root mount.
# blkid uses an empty cache so cloned labels cannot be hidden by stale entries.
beagley_check_sd_identity() {
  local sysfs_root="${1:-/sys}" label matches selected root_device boot_device
  local partition parent root_parent boot_parent
  for label in BEAGLEY_ROOT BEAGLEYBOOT; do
    matches=$(blkid -c /dev/null -o device -t "LABEL=$label" || true)
    # blkid emits whitespace-free device paths; count every matching device.
    # shellcheck disable=SC2086
    set -- $matches
    if [ "$#" -ne 1 ]; then
      echo "BeagleY-AI: expected one filesystem labeled $label, found $#" >&2
      return 1
    fi
    selected=$(readlink -f "$1") || return 1
    partition=${selected##*/}
    [ -f "$sysfs_root/class/block/$partition/partition" ] || return 1
    parent=$(readlink -f "$sysfs_root/class/block/$partition") || return 1
    parent=${parent%/*}
    parent=${parent##*/}
    case "$parent" in
    mmcblk[0-9]*) ;;
    *)
      echo "BeagleY-AI: $label is not on MMC storage" >&2
      return 1
      ;;
    esac
    [ "$(cat "$sysfs_root/class/block/$parent/device/type")" = SD ] || return 1
    if [ "$label" = BEAGLEY_ROOT ]; then
      root_device=$selected
      root_parent=$parent
    else
      boot_device=$selected
      boot_parent=$parent
    fi
  done
  [ "$root_device" != "$boot_device" ] || return 1
  [ "$root_parent" = "$boot_parent" ] || return 1
  [ "$(blkid -p -s TYPE -o value "$root_device")" = ext4 ] || return 1
  [ "$(blkid -p -s TYPE -o value "$boot_device")" = vfat ] || return 1
}
