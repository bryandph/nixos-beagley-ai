# USB-C device role

`nixosModules.beagley-ai-usb-gadget` explicitly assigns USB0 to peripheral mode
and starts a configfs ACM serial plus ECM Ethernet gadget. USB1 and the four
USB-A host ports remain independent. The module claims `usb:usb0`; any custom
host-role module must claim that same resource with its own owner.

The configuration advertises a self-powered board. Provide adequate independent
board power and an appropriate USB data connection before enabling it. Do not
activate this profile on the acceptance board while USB-C is its only power
source. The controller `31000000.usb` is present in the running kernel, but
host enumeration has not been physically tested.

The service creates `/dev/ttyGS0` and interface `bgyusb0`. It does not assign an
IP address, enable routing or start an unauthenticated console. Consumers can
configure ordinary NixOS networking and an authenticated serial getty as needed.
The USB serial and locally administered Ethernet addresses derive from the
runtime machine ID. Stopping `beagley-usb-gadget.service` unbinds and removes
only its own configfs gadget.

With an independently powered fixture, verify host ACM and ECM enumeration,
serial traffic, network traffic under the consumer's firewall policy, and
stop/start cleanup. The setup follows [Linux configfs gadget documentation](https://docs.kernel.org/usb/gadget_configfs.html).
