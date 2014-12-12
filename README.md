edbian
======

Debian distro builder for the Intel Edison

WIP - it's significantly ugly.

*Notes for the impatient*

edbian.sh creates a Debian installation package for the Intel Edison using 
debootstrap (currently Jessie) and the edison-src Yocto sources.

*Prerequisites*

- Debian, Ubuntu, or other .deb based Linux distro with debootstrap, dosfstools, and zip packages installed
- Recommend apt-catcher on localhost or a local machine to cache the package downloads that debootstrap initiates.  See "DPKG_SERVER=" towards the top of the script.
- Root

*Building*

```
sudo ./edbian.sh
```

will result in "edbian.zip"

```
sudo ./edbian.sh debug
```

does the same as above but leaves the debroot and toFlash directories behind

*Flashing*

```
unzip edbian.zip
cd toFlash
sudo ./flashall.sh
```

and power cycle the Edison

Initial root password is "edison".

*Cleaning up*

```
sudo ./edbian.sh clean
```

Cleans the build files but will not delete the "dl/" directory containing the sources for the kernel, U-Boot, and Edison Yocto.

```
sudo ./edbian.sh distclean
```

like "clean" but deletes dl/

*Notes*

- The flash payloads don't yet support "recovery" flashing.  If "flashall.sh" is not able to see the Edison after power-on, use the recovery option on the standard Yocto distribution, then try flashing edbian.  At some point I want to generate an OSIP U-Boot image for recovery booting, but that's not top priority.
- The Broadcom drivers are installed in the image with DKMS and should rebuild any time a kernel source package is rebuilt.
- Rebuilding the kernel on the Edison isn't tested yet
- Interesting patches: fix for early printk on Edison using HSU2 (ttyMFD2).  Workaround for the boot hang when building outside of the Yocto toolchain (disable FTRACE support).
- None of the usual Edison bits are there yet, this is plain Debian.
- Only the root account is activated, and sshd is configured to allow root plaintext password login.  This doesn't sit well with me, but I can't think of a better way to allow emergency login via hostapd.

*TODO list*

- [ ] Clean up the script
	- [x] Better comments
	- [x] Split up tasks
	- [ ] Fix unclear paths
	- [ ] Minimize time spent in root
	- [ ] Isolate build products on the build host and chroot in separate directory
	- [ ] Make rootless if possible, or minimal root requirement (use fakeroot?) during build
	- [ ] Insure all required licenses get put into either the image or the flash directory
- [ ] Better debug features
	- [ ] Option to interactively drop into the chroot
	- [x] Option to not erase the chroot after the build completes
- [ ] Initial setup and recovery features
	- [x] first-install script port from Yocto
	- [x] hostapd mode on power button 2 second press
	- [x] USB gadget RNDIS network enabled on boot
	- [x] Initial root password setup
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
	- [ ] Remove build tools from the debootstrap
