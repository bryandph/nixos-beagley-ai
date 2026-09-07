# Header expansion

Import the core board module and the desired `nixosModules.beagley-ai-header-*`
profile. These are opt-in routes; the server profile leaves them inactive.
GPIO numbers below are header aliases, not Linux GPIO offsets.

| Profile suffix | Header pins | SoC route |
|---|---|---|
| `gpio14-15` | 8, 10 | main GPIO1 lines 14, 13, no output hog |
| `uart1` | 8 TX, 10 RX | main UART1; debug console remains UART0 |
| `i2c-400khz` | 3 SDA, 5 SCL | MCU I2C0, 400 kHz |
| `spi0` | 24 CS0, 23 CLK, 19 MOSI, 21 MISO | native MCU SPI0, D0 output |
| `pwm14` | 8 | EHRPWM0 B |
| `pwm12` | 32 | ECAP0 |
| `mcasp0` | 12 BCLK, 35 frame clock, 38 RX, 40 TX | McASP0 I2S, two slots |

Routes are adapted from [BeagleBoard DeviceTrees](https://github.com/beagleboard/BeagleBoard-DeviceTrees/tree/d9728dcd588d95ae58defb13318ffd2422c6e9c0/src/arm64),
including its BeagleY-AI pinmux definitions. The kernel's native MCU SPI0
controller replaces the older overlay's software SPI bus. No fictitious SPI
peripheral is declared: the consuming module must describe its actual chip.
The McASP profile exposes the controller and pins; an identified codec,
clock ownership, and sound-card binding are still required for audio playback.

Composition rejects conflicting owners of a pin or controller. UART1 conflicts
with GPIO14/15 and PWM14; PWM12 conflicts with the LCD185 OLDI profile's ECAP0
backlight. CSI/DSI profiles share the same resource mechanism. Claims only cover
provided profiles; custom overlays must declare their own resource claims.

Use 3.3 V logic. The separate header I2C pins 27/28 share the board management
bus with the PMIC, regulator, EEPROM and RTC; do not use indiscriminate bus
scans or writes there. Consult the [board design](https://docs.beagleboard.org/boards/beagley/ai/03-design.html)
and [pin map](https://pinout.beagley.ai/) before wiring.

`gpioinfo`, `gpioget --help`, `i2cdetect -l`, `/sys/class/pwm`, and kernel logs
provide nondestructive discovery. GPIO line requests, SPI exchanges, PWM output,
UART loopback, and I2S recording/playback require appropriate external fixtures.
The profiles have build-time DT and conflict checks; physical header transfers
remain unverified. No fixture waiver is implied.
