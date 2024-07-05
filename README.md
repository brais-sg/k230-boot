# This repository is a fork to experiment with the K230 and Linux on the big core

[Original repository by Rémi Denis-Courmont](https://code.videolan.org/Courmisch/k230-boot)

# Kendryte K230-CanMV Linux boot

This repository provides *all* needed sources to boot the K230-CanMV board
to Linux user-space.

[TOC]

# Motivation

The official [Kendryte K230 SDK](https://github.com/kendryte/k230_sdk)
aims to run a real-time operating system on the "big" C908 found
in the CanMV-K230, with a small Linux system on the "little" core.

This repository on the other hand strives to provide an easier and leaner way
to install a normal Linux distribution (such as Debian, Fedora or Gentoo).
It boots a Linux kernel with support for the RISC-V Vector extension
on the *big* core and with all the RAM.

This repository also dispenses with building the RTOS
and the Busybox build root. The intent is to let *you* install *your* favorite
Linux RISC-V distribution on the root filesystem, while this repository only
builds and makes a tiny flashable image with:
* The two stages of boot loader: U-boot SPL and U-boot,
* OpenSBI, and
* the Linux kernel.

# Differences from vendor SDK

The main differences are:
* At run time:
  * Running Linux on the "big" core.
  * Support for the RISC-V Vector extension for Linux user-space.
  * Full system 512 MiB of RAM available.
  * Only 4 MiB of storage reserved for boot loader.
  * Kernel image in /boot with U-boot syslinux-style distro boot support.
  * Backported bug fixes for the onboard Ethernet adapter (RealTek 8152).
* At build time:
  * Support for non-x86-64 (incl. native RISC-V) host.
  * Support for parallel builds (vendor requires `make -j1`).
  * Support for upstream GCC cross-compilation toolchain.
  * Compatibility with up-to-date host glibc.
  * No external downloads (except for git submodules).
  * No RTOS.
  * No Buildroot/Busybox root file system (pick your own!).
  * No executable binaries without sources.

# Disclaimer

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Installation

**WARNINGS**:
* Make sure that you have backed up any data from the microSD card.
  Existing data will be overwritten and permanently lost.
* Ascertain the correct device node for the microSD card whilst flashing.
  If you use another device node, you may erase the data on your hard-drive
  or whatever else.

The following instructions assume that you have a Linux (or BSD) desktop
computer. Your mileage may vary if you use another operating system.

* Download and decompress the system image, or [rebuild it](#Build).
* Flash the system image `sysimage-sdcard.img` onto a free microSD card.
  For instance, if the SD card device node is `/dev/sdz`:
```
# dd if=sysimage-sdcard.img of=/dev/sdz bs=1M conv=sync
```
* Edit the partition table of microSD card with an ad-hoc tool,
  such as GNU Parted to:
  * extend the partition table to the entire SD card and
  * resize the "`rootfs`" (number 5) root partition.
* Resize the file system of the root partition.
* Install a Linux RISC-V distribution on the root partition:
  * [Debian GNU/Linux](https://www.remlab.net/op/k230-canmv-debian.shtml).
* Put the microSD card into the TF slot of the K230-CanMV board and power on.

# Troubleshooting

The board has a built-in serial port available through the USB CDC ACM protocol
on the power USB-C port.

To troubleshoot, connect the board with the provided USB cable to a free port
on a Linux desktop, and attach to the serial port, e.g.:
```
$ cu -l ttyACM0
```

## U-boot enviroment CRC errors

By default, the partition (number 3) to store the U-boot environment is empty,
and therefore invalid as far as U-boot is concerned. This is deliberate: we
want U-boot to use its default settings.

The error is essentially harmless. But if you want to avoid it anyway,
just save the current environment from the U-boot command line prompt.

## Ethernet interface reports no link (no carrier)

There is a known issue with the RealTek 8152 USB Ethernet adapter,
whereby it does not detect the link. To work around this, disable Ethernet
auto-negotiation and force a link speed of 10 MBits/s, e.g.:
```
# ethtool -s eth0 autoneg off speed 10 duplex full
```
Note that [the vendor kernel is even worse off](https://github.com/kendryte/k230_sdk/issues/35).

# Build

To rebuild the system image yourself:

* Install the `riscv64-linux-gnu-gcc`, GNU/make, `xxd`, `gawk`, `sfdisk`,
  `fakeroot` and Python 3, e.g.:
```
# apt-get install install gcc-riscv64-linux-gnu make xxd gawk fdisk \
                             fakeroot python3
```
* Clone this repository and rebuild:
```
$ git clone --recurse-submodules \
	https://code.videolan.org/Courmisch/k230-boot.git
$ cd k230-boot
$ make
```

# Contact

You can submit merge requests or issues on this project.
If you need to get a new Gitlab account approved,
contact the `#videolan` IRC channel on Libera chat.

For technical discussions regarding this project,
you can contact `courmisch` on the `#riscv` IRC channel also on Libera chat.
