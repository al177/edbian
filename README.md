edbian
======

Debian distro builder for the Intel Edison

WIP - it's significantly ugly.

Notes for the impatient:

edbian.sh creates a Debian installation package for the Intel Edison using 
debootstrap (currently Jessie) and the edison-src Yocto sources.

Prerequisites:

-Debian, Ubuntu, or other .deb based Linux distro with debootstrap, dosfstools,
 and zip packages installed

-Recommend apt-catcher on localhost or a local machine to cache the package
 downloads that debootstrap initiates.  See "DPKG_SERVER=" towards the top of
 the script.

-Root

Building:

"sudo ./edbian.sh"

will result in "edbian.zip"

Flashing:

"unzip edbian.zip; cd toFlash; sudo ./flashall.sh"

and power cycle the Edison

Cleaning up:

"sudo ./edbian.sh clean" : Cleans the build files but will not delete the "dl/"
 directory containing the sources for the kernel, U-Boot, and Edison Yocto.

"sudo ./edbian.sh distclean" : like "clean" but deletes dl/

Notes:

-The flash payloads don't yet support "recovery" flashing.  If "flashall.sh" is
 not able to see the Edison after power-on, use the recovery option on the
 standard Yocto distribution, then try flashing edbian.  At some point
 I want to generate an OSIP U-Boot image for recovery booting, but that's not
 top priority.

-Networking is untested.  USB gadget support is untested.

-The Broadcom drivers are installed in the image with DKMS and should rebuild
 any time a kernel source package is rebuilt.

-Rebuilding the kernel on the Edison isn't tested yet

-Interesting patches: fix for early printk on Edison using HSU2 (ttyMFD2).
 Workaround for the boot hang when building outside of the Yocto toolchain
 (disable FTRACE support).

-None of the usual Edison bits are there yet, this is plain Debian.

TODO list:

-Clean up the script: split some tasks, better comments

-Minimize root use

-Build minimal version without build-essential: this would require 2 passes:
 one to build the kernel, drivers, and U-Boot, and another debootstrap w/o
 tools.  I'm a debootstrap noob, so there may be an easier way than two
 full debootstraps

-Better debug features: option to interactively drop into the chroot,
 option to leave the chroot after the build completes

-Make build directory on host and chroot to keep the ugly out of pwd

-Add all the missing stuff that makes Edison interesting

-Tighten up the install size: unused locales are already trimmed, but there's
 probably a lot of unnecessary Debian cruft
