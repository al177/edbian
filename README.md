eDbian
======

Debian distro builder for the Intel Edison

WIP - use at your own risk.



# Intro

edbian.sh creates a Debian installation package for the Intel Edison using debootstrap (currently Jessie) and the edison-src Yocto sources.

## Why, when Ubilinux already exists?

Because I like Debian but want more control of what goes into the flashable image.  Because building a Debian embedded distro from bootloader to debootstrap sounded like fun.  But mainly because I wanted something I could smugly call "eDbian".

Currently Ubilinux is much more polished, so if you want Debian that "just works" right now then eDbian isn't for you.

## What's different from Yocto?

At the moment, none of the IoT devkit stuff is installed.  No OTA.  And it's Debian.

## What's different from Ubilinux?

No IoT devkit stuff, uses systemd, and only the root user is configured by default.  I added the access point mode feature from Yocto, which enables when the power button is held for 2 seconds.  The kernel source package is included and the Broadcom WiFi driver is installed with DKMS, so the kernel can be rebuilt natively.

## Why is there no eDbian repository or download site?

Because eDbian is intended to be customized and built.  I'd consider regular builds but I don't have a place to host big files.

## Why one big bash script?  Why not ${FAVORITE_BUILD_TOOL}?

eDbian relies mostly on other packages, namely components from edison-src, so there are very few inlined patches and files.  I didn't see a need to split the build steps into separate modules as it's just not that complex.  A single shell script also makes it easier to call itself within the chroot without additional debootstrap dependencies.

I could have done this with a Makefile, but I feel that make is better suited to applying a build rule to multiple targets, while each task in edbian.sh is unique.  Writing a function for marking tasks as complete was straightforward in bash.  Finally, all of the operations are based on calling external programs, so there would be very little advantage to doing this in a Python or Perl script.

# Prerequisites for building

- Debian, Ubuntu, or other .deb based Linux distro with debootstrap, dosfstools, and zip packages installed
- Recommend apt-catcher on localhost or a local machine to cache the package downloads that debootstrap initiates.  See "APT_CATCHER=" towards the top of the script.
- Root

# Building

```
sudo ./edbian.sh
```

will result in "edbian.zip"

```
sudo ./edbian.sh debug
```

does the same as above but leaves the debroot and toFlash directories behind

# Flashing

The procedure and requirements are identical for flashing Yocto.  Although eDbian must be built in a Debian based distro, the .zip may be flashed in any of the OSes supported by Yocto.

For Debian, insure that dfu-utils is installed first.

```
unzip edbian.zip
cd toFlash
sudo ./flashall.sh
```

and power cycle the Edison

Initial root password is "edison".

# Cleaning up

```
sudo ./edbian.sh clean
```

Cleans the build files but will not delete the "dl/" directory containing the sources for the kernel, U-Boot, and Edison Yocto.

```
sudo ./edbian.sh distclean
```

like "clean" but deletes dl/

# Notes

- The flash payloads don't yet support "recovery" flashing.  If "flashall.sh" is not able to see the Edison after power-on, use the recovery option on the standard Yocto distribution, then try flashing eDbian.  At some point I want to generate an OSIP U-Boot image for recovery booting, but that's not top priority.
- The Broadcom drivers are installed in the image with DKMS and should rebuild any time a kernel source package is rebuilt.
- Rebuilding the kernel on the Edison isn't tested yet
- Interesting patches: fix for early printk on Edison using HSU2 (ttyMFD2).  Workaround for the boot hang when building outside of the Yocto toolchain (disable FTRACE support).
- None of the usual Edison bits are there yet, this is plain Debian.
- Only the root account is activated, and sshd is configured to allow root plaintext password login.  This doesn't sit well with me, but I can't think of a better way to allow emergency login via hostapd.

# TODO list

- [ ] Clean up the script
	- [X] Better comments
	- [X] Split up tasks
	- [ ] Fix unclear paths
	- [ ] Minimize time spent in root
	- [ ] Isolate build products on the build host and chroot in separate directory
	- [ ] Make rootless if possible, or minimal root requirement (use fakeroot?) during build
- [ ] Distro improvements
	- [ ] Insure all required licenses get put into either the image or the flash directory
	- [ ] Create default non-root user with sudo privs for root and any hardware access
	- [ ] Disable sshd passwordless root
- [ ] Better debug features
	- [ ] Option to interactively drop into the chroot
	- [X] Option to not erase the chroot after the build completes
- [ ] Initial setup and recovery features
	- [X] first-install script port from Yocto
	- [X] hostapd mode on power button 2 second press
	- [X] USB gadget RNDIS network enabled on boot
	- [X] Initial root password setup
	- [ ] OTA install image support (not sure if practical)
	- [ ] OSIP U-Boot image for worst-case recovery
	- [ ] connman for easier network setup (maybe?)
- [ ] Package libraries and other bits needed for Edison specific development (low priority for now)
	- [ ] libmraa
	- [ ] SDK integration components
		- [ ] MQTT tools
		- [ ] Bonjour / mdns
		- [ ] nodejs
		- [ ] xdk-daemon
	- [ ] iotkit-* tools (agent, comm)
	- [ ] upm
- [ ] Tighten up the install size
	- [ ] Make currently unpackaged components into deb packages (firmwares, power button tool, wifi driver)
	- [ ] Build packages in separate chroot
	- [ ] Copy all packages into the debootstrap chroot, but install only required (kernel, drivers, etc).
		- [ ] (optional) Set up repository somewhere and keep the packages out of the image
	- [ ] Remove build tools from the debootstrap, or make optional

