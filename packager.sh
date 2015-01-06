#!/bin/bash

#. ./edbian.sh

EDISON_SRC=edison-src-rel1-maint-rel1-ww42-14.tgz

EDSRC_VER=`sed -ne "s/.*-ww\([0-9]*\)-\([0-9]*\).*/20\2.\1/p" <<<"${EDISON_SRC}"`

echo "edison-src is ${EDISON_SRC}, dpkg version is ${EDSRC_VER}"

SRC=${PWD}/src
EDSRC_BASE=${PWD}/edison-src
PKG_SKEL_DIR=${PWD}/pkgs
DEBS_DIR=${PWD}/debs

function build_basic_pkg() {
	echo "in build_basic_pkg"
	echo "pkgname = $PKG_NAME"
	cp -a DEBIAN ${PKG_NAME}
	sed -i -e "s/##VERSION##/${EDSRC_VER}/g" ${PKG_NAME}/DEBIAN/control
	fakeroot dpkg-deb --build ${PKG_NAME}
}

function build_src_pkg() {
	echo "in build_src_pkg"
	echo "pkgname = $PKG_NAME"
	cp -a DEBIAN ${PKG_NAME}
	sed -i -e "s/##VERSION##/${EDSRC_VER}/g" ${PKG_NAME}/DEBIAN/control
	fakeroot dpkg-deb --build ${PKG_NAME}
}

pushd $PKG_SKEL_DIR
for CUR_PKG in *; do
	PKG_NAME="${CUR_PKG}_${EDSRC_VER}"
	pushd $CUR_PKG
	. ./make_pkg
	mv *deb ${DEBS_DIR}
	rm -rf ${PKG_NAME}
	popd
done
popd


