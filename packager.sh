#!/bin/bash

#. ./edbian.sh

EDISON_SRC=edison-src-rel1-maint-rel1-ww42-14.tgz

EDSRC_VER=`sed -ne "s/.*-ww\([0-9]*\)-\([0-9]*\).*/20\2.\1/p" <<<"${EDISON_SRC}"`

echo "edison-src is ${EDISON_SRC}, dpkg version is ${EDSRC_VER}"

SRC=${PWD}/src
EDSRC_BASE=${PWD}/edison-src
PKG_SKEL_DIR=${PWD}/pkgs
DEBS_DIR=${PWD}/debs

function build_src_pkg() {
	PKG_NAME=$1
	echo "pkgname = $PKG_NAME"

	# delete function remnants from previous iteration
	unset -f build_prep
	unset -f build_fixup

	# source package build file
	. ./make_pkg
	if type -t build_prep > /dev/null; then
		build_prep
	fi
	pushd $PKG_NAME
	export QUILT_PATCHES=debian/patches
	export QUILT_REFRESH_ARGS="-p ab --no-timestamps --no-index"
	export LANG=C
	dh_make -y --createorig -p ${PKG_NAME} -s
	mkdir -p ${PKG_NAME}/${QUILT_PATCHES}
	if [ -e ../patches ]; then
		for PATCH in `ls -1 ../patches`; do
			quilt import ../patches/$PATCH
		done
	fi
	if [ -e ../files ]; then
		quilt new addfiles-${PKG_NAME}.patch
		# prime quilt with the new files
		NEWFILES=`find ../files -type f  | sed -e "s/\.\.\/files\///g"`
		for FILE in ${NEWFILES}; do
			quilt add $FILE
		done
		# now that quilt expects the files, copy them
		cp -a ../files/. .
		# sync the patch and remove it
		quilt refresh
		quilt pop -a
	fi
	quilt push -a
	if [ -e ../debian_patches ]; then
		for PATCH in `ls -1 ../debian_patches`; do
			patch -p1 < ../debian_patches/$PATCH
		done
	fi

	# run post unpack and patch fixup.  this is where debian/ customization
	# should happen
	if type -t build_fixup > /dev/null; then
		build_fixup
	fi
	dpkg-buildpackage -us -uc
	popd
}

mkdir -p ${DEBS_DIR}
pushd ${PKG_SKEL_DIR}
if [ -n "$1" ]; then
	PKGS="$1"
else
	PKGS="`ls -1`"
fi
for CUR_PKG in ${PKGS}; do
	PKG_NAME="${CUR_PKG}_${EDSRC_VER}"
	rm ${DEBS_DIR}/${CUR_PKG}*
	pushd ${CUR_PKG}
	build_src_pkg ${PKG_NAME}
	mv ${PKG_NAME}?* ${DEBS_DIR}
	popd
done
popd


