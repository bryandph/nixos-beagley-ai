#!/usr/bin/env bash
set -euo pipefail
root=/sys/kernel/config/usb_gadget/beagley-ai
cleanup() {
  [ -d "$root" ] || return 0
  if [ -s "$root/UDC" ]; then echo '' >"$root/UDC"; fi
  for function in acm.usb0 ecm.usb0; do
    [ ! -L "$root/configs/c.1/$function" ] || rm "$root/configs/c.1/$function"
    [ ! -d "$root/functions/$function" ] || rmdir "$root/functions/$function"
  done
  [ ! -d "$root/configs/c.1/strings/0x409" ] || rmdir "$root/configs/c.1/strings/0x409"
  [ ! -d "$root/configs/c.1" ] || rmdir "$root/configs/c.1"
  [ ! -d "$root/strings/0x409" ] || rmdir "$root/strings/0x409"
  rmdir "$root"
}
case "${1:-}" in
stop)
  cleanup
  exit 0
  ;;
start) ;;
*)
  echo 'Expected start or stop' >&2
  exit 2
  ;;
esac
cleanup
for ((attempt = 0; attempt < 30; attempt++)); do
  [ ! -d /sys/class/udc/31000000.usb ] || break
  sleep 1
done
test -d /sys/class/udc/31000000.usb
mkdir "$root"
trap cleanup ERR
cd "$root"
echo 0x1d6b >idVendor
echo 0x0104 >idProduct
echo 0x0200 >bcdUSB
echo 0x0100 >bcdDevice
mkdir strings/0x409 configs/c.1 configs/c.1/strings/0x409
serial=$(cat /etc/machine-id)
printf '%s\n' "$serial" >strings/0x409/serialnumber
echo Linux >strings/0x409/manufacturer
echo 'BeagleY-AI serial and Ethernet' >strings/0x409/product
echo 'ACM + ECM' >configs/c.1/strings/0x409/configuration
# The configuration describes a self-powered board, not host-supplied board power.
echo 0xc0 >configs/c.1/bmAttributes
echo 2 >configs/c.1/MaxPower
mkdir functions/acm.usb0 functions/ecm.usb0
hash=$(printf '%s' "$serial" | sha256sum)
suffix=${hash:0:2}:${hash:2:2}:${hash:4:2}:${hash:6:2}:${hash:8:2}
echo "02:$suffix" >functions/ecm.usb0/dev_addr
echo "06:$suffix" >functions/ecm.usb0/host_addr
echo bgyusb0 >functions/ecm.usb0/ifname
ln -s "$root/functions/acm.usb0" configs/c.1/acm.usb0
ln -s "$root/functions/ecm.usb0" configs/c.1/ecm.usb0
echo 31000000.usb >UDC
