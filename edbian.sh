#!/bin/bash

#edbian.sh - Debian distro generator for the Intel Edison
#Copyright (C) 2014 Andrew Litt
# 
#This program is free software; you can redistribute it and/or
#modify it under the terms of the GNU General Public License
#as published by the Free Software Foundation; either version 2
#of the License, or (at your option) any later version.
# 
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
# 
#You should have received a copy of the GNU General Public License
#along with this program; if not, write to the Free Software
#Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

BASE=$PWD
DL_PATH=${BASE}/dl
ROOT_PATH=${BASE}/debroot
FLASHER=${BASE}/toFlash
THIS_SCRIPT=`basename $0`
OUTPUT_ZIP=edbian.zip

MAKEOPTS="-j3"

ARCH=i386
DIST=jessie

# A local apt-catcher server is recommended for development to keep from
# downloading all the packages every time debootstrap is run.  On Ubuntu
# and Debian, "apt-get install apt-catcher" should be all that's needed.  If
# you're sure that you want to pull directly from the network, swap the
# commenting on the next two lines.
#DPKG_SERVER=http://http.debian.net/debian/
DPKG_SERVER=http://localhost:3142/http.debian.net/debian/

CH_PKG_PATH=${ROOT_PATH}/usr/src
MKIMAGE=/usr/src/u-boot-*/tools/mkimage
MKENVIMAGE=/usr/src/u-boot-*/tools/mkenvimage
UBOOT_ENVS=/usr/src/u-boot-envs
CH_U_BOOT_ENVS=${ROOT_PATH}${UBOOT_ENVS}

BOOTFS_FILE=${FLASHER}/edison-image-edison.hddimg
ROOTFS_FILE=${FLASHER}/edison-image-edison.ext4

# for edbian, rootfs steals from updatefs in the partition layout.  Edit
# ROOTFS_SIZE= below to a size of 512 to 1240.
BOOTFS_SIZE=8 # in MB
ROOTFS_SIZE=1024 # in MB
UPDATEFS_SIZE=$(( 1280 - ROOTFS_SIZE )) 

TEMP_MNTPT=${BASE}/mnt

# Needed for the build: U-Boot source, kernel source, Edison Yocto build tree
FILES_TO_GET="\
http://downloadmirror.intel.com/24389/eng/edison-src-rel1-maint-rel1-ww42-14.tgz \
https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.10.17.tar.bz2 \
ftp://ftp.denx.de/pub/u-boot/u-boot-2014.04.tar.bz2"

# Packages to install on top of minbase
TARGET_MIN_PKGS="u-boot-tools,dosfstools,wpasupplicant,wireless-tools,netbase,ifupdown,net-tools,isc-dhcp-client,localepurge,vim-tiny,nano,dbus,openssh-server,openssh-client,wget"

# Packages needed for building.  TODO: make toolchain-less build
TARGET_BUILD_PKGS="build-essential,bc,dkms,fakeroot,debhelper"

# Check that these are available on the build host
HOST_PKGS_REQUIRED="dosfstools zip"

DEBUG=0
FAIL=0

function is_in_chroot() {
	[ "`dirname $0`" == "/usr/src" ]
}

# Patch to fix early printk in the Edison Yocto kernel patch
PATCH_KERN_HSU_FILE=/usr/src/edison_early_printk_hsu.patch
if is_in_chroot; then 
cat > $PATCH_KERN_HSU_FILE <<'HeREPaTCH1'
--- linux-3.10.17/arch/x86/platform/intel-mid/early_printk_intel_mid.c	2014-11-22 23:05:46.062552675 -0600
+++ linux-new/arch/x86/platform/intel-mid/early_printk_intel_mid.c	2014-11-30 17:16:57.515386274 -0600
@@ -397,7 +397,7 @@
 /*
  * Following is the early console based on High Speed UART device.
  */
-#define MERR_HSU_PORT_BASE	0xff010180
+#define MERR_HSU_PORT_BASE	0xff010080
 #define MERR_HSU_CLK_CTL	0xff00b830
 #define MFLD_HSU_PORT_BASE	0xffa28080
 
@@ -444,6 +444,8 @@
 		/* detect HSU clock is 50M or 19.2M */
 		if (clkctl && *clkctl & (1 << 16))
 			writel(0x0120, phsu + UART_MUL * 4); /* for 50M */
+		else if (*clkctl & (1 << 31))
+			writel(0x02EE, phsu + UART_MUL * 4);  /* for 38.4M */
 		else
 			writel(0x05DC, phsu + UART_MUL * 4);  /* for 19.2M */
 	} else
HeREPaTCH1
fi

# call with $FUNCNAME, returns 0 if already run
function task_start() {
	if [ -e ${BASE}/checkpoint_$1 ]; then
		echo "---$1 skip - already done"
		return 0
	fi
	if [ $FAIL -ne 0 ]; then
		echo "---$1 skip - previous task failed"
		return 0
	fi
	echo "---$1 start"
	return 1			
}

# call with $FUNCNAME
function task_mark_complete() {
	if [ $? -eq 0 ]; then
		echo "---$1 complete"
		touch ${BASE}/checkpoint_$1
	else
		echo "---$1 failed"
		FAIL=1
	fi
}


function do_chroot_tasks() {
	if task_start $FUNCNAME; then
		return 0
	fi	
	cp $0 ${ROOT_PATH}/usr/src &&
	mount -t proc proc ${ROOT_PATH}/proc &&
	mount -t sysfs sysfs ${ROOT_PATH}/sys
	if [ $? -ne 0 ]; then
		umount ${ROOT_PATH}/proc
		umount ${ROOT_PATH}/sys
		false
		task_mark_complete $FUNCNAME
		return 1
	fi

	setarch i686 chroot ${ROOT_PATH} /bin/bash /usr/src/$THIS_SCRIPT
	[ ! -e ${CH_PKG_PATH}/fail ]
	task_mark_complete $FUNCNAME
	umount ${ROOT_PATH}/proc
	umount ${ROOT_PATH}/sys
}

function do_check_prereqs() {
	if task_start $FUNCNAME; then
		return 0
	fi	
	dpkg-query -l ${HOST_PKGS_REQUIRED}
	task_mark_complete $FUNCNAME 	
}


function do_download_stuff() {
	if task_start $FUNCNAME; then
		return 0
	fi
	MISSING=0
	mkdir -p $DL_PATH
	for FILE in $FILES_TO_GET; do
		wget -nc -P $DL_PATH $FILE
		if [ $? -ne 0 ]; then
			MISSING=$(( MISSING + 1 ))
		fi
	done
	[ $MISSING -eq 0 ]
	task_mark_complete $FUNCNAME
}

function do_unpack_stuff() {
	if task_start $FUNCNAME; then
		return 0
	fi	
	if ! grep -q debroot <<<"${CH_PKG_PATH}"; then
		echo "Internal path error, bailing!"
		exit 255 
	fi
	rm -rf ${CH_PKG_PATH}/*
	tar -xjf ${DL_PATH}/linux-*bz2 -C ${CH_PKG_PATH} &&
	tar -xzf ${DL_PATH}/edison-src*tgz -C ${CH_PKG_PATH} &&
	tar -xjf ${DL_PATH}/u-boot*bz2 -C ${CH_PKG_PATH} &&
	task_mark_complete $FUNCNAME
}

function do_debootstrap() {
	if task_start $FUNCNAME; then
		return 0
	fi	
	if [ -d ${ROOT_PATH} ]; then
		rm -rf $ROOT_PATH/* 2>/dev/null
	else
		mkdir -p $ROOT_PATH
	fi
	
	debootstrap --include="${TARGET_MIN_PKGS},${TARGET_BUILD_PKGS}" --arch ${ARCH} --variant=minbase ${DIST} ${ROOT_PATH} ${DPKG_SERVER}
	if [ $? -ne 0 ]; then
		echo "debootstrap error"
		rm -rf ${ROOT_PATH}
		false
		task_mark_complete $FUNCNAME
		return 1
	fi
	# setup before chroot
	echo "edbian.local" > ${ROOT_PATH}/etc/hostname &&
	echo "127.0.0.1	localhost edbian edbian.local" > ${ROOT_PATH}/etc/hosts &&
	echo -e "ttyMFD0\nttyMFD1\nttyMFD2" >> ${ROOT_PATH}/etc/securetty &&
	sed -i -e "s/root:\*/root:/g" ${ROOT_PATH}/etc/shadow &&
	echo -e "/dev/disk/by-partlabel/u-boot-env0 0x0000 0x10000 0x10000\n/dev/disk/by-partlabel/u-boot-env1 0x0000 0x10000 0x10000" > ${ROOT_PATH}/etc/fw_env.config
	task_mark_complete $FUNCNAME
}

# after debootstrap, in chroot, before doing anything else
function ch_do_debootstrap_post() {
	if task_start $FUNCNAME; then
		return 0
	fi
	echo "en_US.UTF-8" >> /etc/default/locale &&
	locale-gen en_US.UTF-8 &&
	localepurge &&
	# systemd optional mounts
	# note: not sure if this is the right place for the .wants, reenable
	# once it's figured out
	install -m 0644 ${BASE}/edison-src/device-software/meta-edison-distro/recipes-core/base-files/base-files/fstab /etc/fstab &&
	install -m 0644 ${BASE}/edison-src/device-software/meta-edison-distro/recipes-core/base-files/base-files/*mount /lib/systemd/system &&
#	ln -sf /lib/systemd/system/media-sdcard.mount /etc/systemd/system/default.target.wants/media-sdcard.mount &&
#	ln -sf /lib/systemd/system/factory.mount /etc/systemd/system/default.target.wants/factory.mount &&
	# systemd first-install setup
	FIRST_INSTALL_PATH=${BASE}/edison-src/device-software/meta-edison-distro/recipes-core/first-install/files &&
	install -m 0644 ${FIRST_INSTALL_PATH}/first-install.target /lib/systemd/system &&
	install -m 0644 ${FIRST_INSTALL_PATH}/first-install.service /lib/systemd/system &&
	install -m 0755 ${FIRST_INSTALL_PATH}/first-install.sh /sbin &&
	install -d /etc/systemd/system/first-install.target.wants &&
	ln -sf ${FIRST_INSTALL_PATH}/first-install.service /etc/systemd/system/first-install.target.wants/first-install.service &&
	sed -i -e "s/mkfs.ext4 -m0/mkfs.ext4 -m0 -F/g" /sbin/first-install.sh &&
	sed -i "/ExecStart/d" /lib/systemd/system/first-install.service &&
	echo "ExecStart=/bin/sh /sbin/first-install.sh systemd-service" >> /lib/systemd/system/first-install.service &&
	sed -i -e "s/#.*RuntimeWatchdog.*$/RuntimeWatchdogSec=60s/g" /etc/systemd/system.conf &&
	# don't do the /home/root copy
	sed -i "/\/root/d" /sbin/first-install.sh &&
	# Debian builds host keys for sshd, skip
	sed -i -e "s/sshd_init\$/true/g" /sbin/first-install.sh &&
	# Not sure about hostapd address setup... skip for now
	sed -i -e "s/setup_ap_ssid_and_passphrase\$/true/g" /sbin/first-install.sh &&
	systemctl enable serial-getty@ttyMFD2.service &&
	systemctl enable serial-getty@ttyGS0.service &&
	systemctl disable getty@tty1.service &&
	echo "g_multi" >> /etc/modules &&
	echo "options g_multi file=/dev/mmcblk0p9" > /etc/modprobe.d/g_multi.conf
	task_mark_complete $FUNCNAME
}

# note: sources are installed into DKMS cache, so the unpacked dir
# is deleted at the end
function ch_do_bcm_wifi() {
	if task_start $FUNCNAME; then
		return 0
	fi
	cp -av /usr/src/edison-src/broadcom_cws/wlan/driver_bcm43x \
		/usr/src/driver_bcm43x-1.0
	pushd /usr/src
	DKMS_CONF=driver_bcm43x-1.0/dkms.conf
	echo "MAKE=\"make KERNEL_SRC=\$kernel_source_dir\"" >$DKMS_CONF &&
	echo "CLEAN=\"make clean\"" >> $DKMS_CONF &&
	echo "BUILT_MODULE_NAME=bcm4334x" >> $DKMS_CONF &&
	echo "DEST_MODULE_LOCATION=/extras" >> $DKMS_CONF &&
	echo "PACKAGE_NAME=bcm43x" >> $DKMS_CONF &&
	echo "PACKAGE_VERSION=1.0" >> $DKMS_CONF &&
	echo "REMAKE_INITRD=no" >> $DKMS_CONF &&
	dkms add -k 3.10.17-poky-edison/i686 -m driver_bcm43x -v 1.0 &&
	dkms build -k 3.10.17-poky-edison/i686 -m driver_bcm43x -v 1.0 &&
	dkms install -k 3.10.17-poky-edison/i686 -m driver_bcm43x -v 1.0 &&
	rm -rf driver_bcm43x-1.0	
	task_mark_complete $FUNCNAME
	popd
}

function ch_do_bcm_wifi_fw_install() {
	if task_start $FUNCNAME; then
		return 0
	fi
	pushd /usr/src/edison-src/broadcom_cws/wlan/firmware
        install -v -d  /etc/firmware/ &&
        install -m 0755 bcmdhd_aob.cal_4334x_b0 /etc/firmware/bcmdhd_aob.cal &&
        install -m 0755 bcmdhd.cal_4334x_b0 /etc/firmware/bcmdhd.cal &&
        install -m 0755 fw_bcmdhd_p2p.bin_4334x_b0 /etc/firmware/fw_bcmdhd.bin &&
        install -m 0755 LICENCE.broadcom_bcm43xx /etc/firmware/ &&
	echo "options bcm4334x firmware_path=/etc/firmware/fw_bcmdhd.bin nvram_path=/etc/firmware/bcmdhd.cal" > /etc/modprobe.d/bcm4334x.conf
	task_mark_complete $FUNCNAME
	popd
}

function ch_do_bcm_bt_fw_install() {
	if task_start $FUNCNAME; then
		return 0
	fi
	pushd /usr/src/edison-src/broadcom_cws/bluetooth/firmware
        gcc -O2 -o brcm_patchram_plus brcm_patchram_plus.c &&
	install -v -d  /etc/firmware/ &&
        install -m 0755 BCM43341B0_002.001.014.0122.0166.hcd /etc/firmware/bcm43341.hcd &&
        install -v -d  /usr/sbin/ &&
        install -m 0755 brcm_patchram_plus /usr/sbin/
	task_mark_complete $FUNCNAME
	popd
}

function do_pkginst() {
	if task_start $FUNCNAME; then
		return 0
	fi	
	apt-get -y install ${TARGET_MIN_PKGS}
	task_mark_complete $FUNCNAME
}

function ch_do_kernel() {
	if task_start $FUNCNAME; then
		return 0
	fi	
	EDISRC_PATH=${BASE}/edison-src
	if [ ! -d ${EDISRC_PATH} ]; then
		echo "edison source not found"
		false
		task_mark_complete $FUNCNAME
		return 1
	fi
	pushd ${BASE}/linux-* &&\
	EDIKERN_PATH=${EDISRC_PATH}/device-software/meta-edison/recipes-kernel/linux/files &&\
	patch -p1 < ${EDIKERN_PATH}/upstream_to_edison.patch &&
	patch -p1 < ${PATCH_KERN_HSU_FILE} &&
	sed -i -e "s/march=slm/march=silvermont/g" arch/x86/Make* &&
	sed -i -e "s/mtune=slm/mtune=silvermont/g" arch/x86/Make* &&
	cp ${EDIKERN_PATH}/defconfig .config &&
	sed -i -e "s/CONFIG_FTRACE=y/# CONFIG_FTRACE is not set/g" .config &&
	echo "# CONFIG_KMEMCHECK is not set" >> .config &&
	cp drivers/tty/serial/mfd_trace.h include/trace/ &&
	make ${MAKEOPTS} silentoldconfig &&
	DEBEMAIL="edison@debian" \
		make ${MAKEOPTS} deb-pkg
	task_mark_complete $FUNCNAME
	popd
}

function ch_do_kernel_install() {
	if task_start $FUNCNAME; then
		return 0
	fi	
	dpkg -i /usr/src/linux*deb
	task_mark_complete $FUNCNAME
}

# U-Boot / payload notes:
# Partitions
#	1MB	OSIP + MBR + GPT
#	2MB	u-boot0
#	1MB	u-boot-env0
#	2MB	u-boot1
#	1MB	u-boot-env1
#	1MB	factory
#	24MB	panic
#	32MB	boot
#	512MB	rootfs
#	768MB	update
#	-end	home
#	
# IFWI eMMC boot process
#	On-chip boot rom inits eMMC and loads IFWI from the MMC boot partitions
#		(mmcboot, not part of normal disk geometry)
#		boot partitions are 4MB, 2 each
#		(not sure) identical for redundancy
#	IFWI looks for OSIP header at top of eMMC (MBR boot block)
#	(need clarification) If u-boot not found, try alt u-boot image
#		5MB into the eMMC
#	U-Boot image doesn't need to be cooked
#
# recovery boot process
#	On-chip boot rom waits for DFU connection from xFSTK
#	xFSTK sends "_dnx_fwr.bin" and "_dnx_osr.bin" IFWI images
#	Recovery starts
#	xFSTK sends u-boot.img and "real" ifwi 
#		u-boot.img is written directly to eMMC starting at block 0
#		u-boot.img contains OSIP+MBR, GPT, u-boot and env 0 and 1
#	IFWI reboots and reloads from flash copy
#	Note that u-boot is modified so that writing the GPT does a
#		read-modify-write of the MBR so that the OSIP header doesn't
#		get destroyed on DFU
#
# DFU process
#	U-Boot probes for DFU mode on boot (3 sec delay)
#	dfu script sends images to be written to eMMC via U-Boot to the named
#		partitions
#	dfu script asks U-Boot to reset the target
#	edison_ifwi-dbg-XX-dfu.bin: IFWI images for various targets
#	edison-image-edison.hddimg: boot partition contents
#	edison-image-edison.ext4: ext4 rootfs contents
#
# U-Boot envs
#
# Factory partition
# 	Contains BT address and serial number.  SN is plaintext that is
#		printed on the label.  BT MAC is plaintext but is not 
#		available elsewhere so be careful with this partition!
#

function ch_do_u-boot_build() {
	if task_start $FUNCNAME; then
		return 0
	fi
	pushd /usr/src/u-boot*
	patch -p1 < /usr/src/edison-src/device-software/meta-edison-distro/recipes-bsp/u-boot/files/upstream_to_edison.patch &&
	# hack to fix build error - take out irqinfo cmd
	sed -i "/CONFIG_CMD_IRQ/d" include/configs/edison.h &&
	make edison_config &&
	make ${MAKEOPTS} all
	if [ $? -ne 0 ]; then
		false
		task_mark_complete $FUNCNAME
		popd
		return 1
	fi
	# pad the beginning of u-boot.bin to start at ofs 0x1000 (4096b)
	# and pad up to 4096 blocks
	rm -f u-boot-edison.bin
	dd if=u-boot.bin of=u-boot-edison.bin ibs=4096 obs=4096 seek=1 conv=notrunc conv=sync
	task_mark_complete $FUNCNAME
	popd
	#TODO: cook OSIP U-Boot for recovery
}

function ch_do_u-boot-envs_build() {
	if task_start $FUNCNAME; then
		return 0
	fi
	mkdir -p ${UBOOT_ENVS}
	pushd /usr/src/edison-src/device-software/meta-edison-distro/recipes-bsp/u-boot/files
	sed -i -e "s/earlyprintk=ttyMFD2,keep/earlyprintk=hsu2/g" edison.env
	sed -i -e "s/console=ttyMFD2/console=ttyMFD2,115200n8/g" edison.env
	# hack, find a better place for this later
	# NB - remove if the systemd watchdog is working
#	sed -i -e "s/loglevel=4/loglevel=8 intel_scu_watchdog_evo.disable_kernel_watchdog=1/g" edison.env
	sed -i -e "s/loglevel=4/loglevel=8/g" edison.env
	sed -i -e "s/rootfs,size=512MiB/rootfs,size=${ROOTFS_SIZE}MiB/g" edison.env
	sed -i -e "s/update,size=768MiB/update,size=${UPDATEFS_SIZE}MiB/g" edison.env
	for TARG_ENV in target_env/*; do
		TARG_NAME_BASE=`basename $TARG_ENV | cut -d "." -f 1`
		TARG_FILE="${UBOOT_ENVS}/edison-${TARG_NAME_BASE}.bin"
		echo "Packing U-Boot environment ${TARG_NAME_BASE}"
		cat edison.env ${TARG_ENV} | \
			grep -v -E "^$|^\#" | \
			${MKENVIMAGE} -s 0x10000 -r -o ${TARG_FILE} -
	done
	popd
	task_mark_complete $FUNCNAME
}

# needed for do_process_ota_script, only run after U-Boot has been installed
function do_build_local_mkimage() {
	if task_start $FUNCNAME; then
		return 0
	fi
	pushd ${ROOT_PATH}/usr/src/u-boot-[0-9]*
	make distclean &&\
	make edison_config &&\
	make tools &&\
	cp tools/mkimage ${BASE}	
	task_mark_complete $FUNCNAME
	popd
}

# must be done after everything is in the flash dir
function do_process_ota_script() {
	if task_start $FUNCNAME; then
		return 0
	fi
	# Preprocess OTA script - from the official post-build script
	# Compute sha1sum of each file under build/toFlash and build an
	# array containing "@@sha1_filename:SHA1VALUE"
	pth_out=${FLASHER}/
	tab_size=$(for fil in $(find $pth_out -maxdepth 1 -type f -printf "%f\n") ; do sha1_hex=$(sha1sum "$pth_out$fil" | cut -c -40); echo "@@sha1_$fil:$sha1_hex" ; done ;)
	# iterate the array and do tag -> value substitution in ota_update.cmd
	for elem in $tab_size ; do IFS=':' read -a fld_elem <<< "$elem"; sed -i "s/${fld_elem[0]}/${fld_elem[1]}/g" ${FLASHER}/ota_update.cmd; done;

	# Convert OTA script to u-boot script
	${BASE}/mkimage -a 0x10000 -T script -C none -n 'Edison Updater script' -d ${FLASHER}/ota_update.cmd ${FLASHER}/ota_update.scr

	# Supress Preprocessed OTA script
	rm -f ${FLASH}/ota_update.cmd

	task_mark_complete $FUNCNAME
}

# Make installation flash skeleton from the Yocto tree
function do_build_flash() {
	if task_start $FUNCNAME; then
		return 0
	fi
	EDPATH=${ROOT_PATH}/usr/src/edison-src
	mkdir -p ${FLASHER}
	pushd ${FLASHER}
	# Copy U-Boot
	cp ${ROOT_PATH}/usr/src/u-boot-[0-9]*/u-boot-edison.bin .
	# Copy U-Boot envs
	cp -av ${ROOT_PATH}/usr/src/u-boot-envs .
	# Copy IFWI
	cp ${EDPATH}/device-software/utils/flash/ifwi/edison/*.bin .
	# Make DFU variants of IFWI images
	for IFWI in *ifwi*.bin; do
    		dd if=${IFWI} of=`basename $IFWI .bin`-dfu.bin bs=4194304 count=1
	done

	# Copy phoneflash XML
	cp ${EDPATH}/device-software/utils/flash/pft-config-edison.xml .

	# Copy flashing script
	cp ${EDPATH}/device-software/utils/flash/flashall.sh . 
	cp ${EDPATH}/device-software/utils/flash/flashall.bat . 
	cp ${EDPATH}/device-software/utils/flash/filter-dfu-out.js . 
	
	sed -i -e "s/--alt u-boot-env1/-R --alt u-boot-env1/g" flashall.sh
	sed -i "/--alt u-boot-env1/a dfu-wait" flashall.sh
	# copy OTA update
	cp ${EDPATH}/device-software/utils/flash/ota_update.cmd . 

	task_mark_complete $FUNCNAME
	popd
}

function do_make_bootfs() {
	if task_start $FUNCNAME; then
		return 0
	fi
	
	mkdir -p ${TEMP_MNTPT}
	
	dd if=/dev/zero of=${BOOTFS_FILE} bs=1M count=${BOOTFS_SIZE} &&\
	mkdosfs ${BOOTFS_FILE} &&\
	mount -o loop ${BOOTFS_FILE} ${TEMP_MNTPT} &&\
	cp ${ROOT_PATH}/boot/vmlinuz* ${TEMP_MNTPT}/vmlinuz
	task_mark_complete $FUNCNAME
	umount ${TEMP_MNTPT}
}

function do_prune_rootfs() {
	if [ $DEBUG -ne 0 ]; then
		return 0
	fi
	if task_start $FUNCNAME; then
		return 0
	fi
	rm -rf ${ROOT_PATH}/usr/src/u-boot*
	rm -rf ${ROOT_PATH}/usr/src/linux-3.*[0-9]
	rm -rf ${ROOT_PATH}/usr/src/linux-headers*edison
	rm -rf ${ROOT_PATH}/usr/src/edison-src
	rm ${ROOT_PATH}/usr/src/edbian.sh
	rm ${ROOT_PATH}/usr/src/checkpoint*
	rm ${ROOT_PATH}${PATCH_KERN_HSU_FILE}
	task_mark_complete $FUNCNAME
}

function do_make_rootfs() {
	if task_start $FUNCNAME; then
		return 0
	fi
	
	mkdir -p ${TEMP_MNTPT}
	
	dd if=/dev/zero of=${ROOTFS_FILE} bs=1M count=${ROOTFS_SIZE} &&\
	mkfs.ext4 ${ROOTFS_FILE} &&\
	mount -o loop ${ROOTFS_FILE} ${TEMP_MNTPT} &&\
	cp -av ${ROOT_PATH}/* ${TEMP_MNTPT}/.
	task_mark_complete $FUNCNAME
	umount ${TEMP_MNTPT}
}

function cleanup_build_files() {
	echo "Removing chroot directory"
	rm -rf ${ROOT_PATH}
	echo "Removing intermediate files"
	rmdir ${TEMP_MNTPT}
	rm -f mkimage
}

function cleanup_build_products() {
	echo "Removing output files"
	rm -rf ${FLASHER}
}

function cleanup_checkpoints() {
	echo "Removing checkpoint files"
	rm -f checkpoint_*
}

function cleanup_downloads() {
	echo "Removing downloaded files"
	rm -rf ${DL_PATH}
}

function do_post_cleanup() {
	if [ $DEBUG -ne 0 ]; then
		return 0
	fi
	if task_start $FUNCNAME; then
		return 0
	fi
	cleanup_build_files
	zip -r -9 ${OUTPUT_ZIP} toFlash
	chmod 777 edbian.zip
	cleanup_build_products
	task_mark_complete $FUNCNAME
}

#
# start here
#

if [ $UID -ne 0 ]; then
	echo "You need to run this as root!!!"
	exit 255
fi

if grep -q "distclean" <<<"$1"; then
	cleanup_build_files
	cleanup_build_products
	cleanup_checkpoints
	cleanup_downloads
	exit 0
fi

if grep -q "clean" <<<"$1"; then
	cleanup_build_files
	cleanup_build_products
	cleanup_checkpoints
	exit 0
fi

#TBD
if grep -q "debug" <<<"$1"; then
	DEBUG=1
fi

if is_in_chroot; then
	echo "---In chroot env"
	BASE=/usr/src
	rm /usr/src/fail
	ch_do_debootstrap_post
	ch_do_kernel
	ch_do_kernel_install
	ch_do_bcm_wifi
	ch_do_bcm_wifi_fw_install
	ch_do_bcm_bt_fw_install
	ch_do_u-boot_build
	ch_do_u-boot-envs_build
	if [ $FAIL -ne 0 ]; then
		touch /usr/src/fail
	fi
else
	echo "---In native env"
	do_check_prereqs
	do_download_stuff
	do_debootstrap
	do_unpack_stuff
	do_chroot_tasks # all is_in_chroot done here
	do_build_flash
	do_build_local_mkimage
	do_make_bootfs
	do_prune_rootfs
	do_make_rootfs
	do_process_ota_script
	do_post_cleanup
fi
