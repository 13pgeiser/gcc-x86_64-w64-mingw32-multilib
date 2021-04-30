#!/bin/sh
set -ex
# VERSIONS
MPFR_VERSION=4.1.0
GMP_VERSION=6.2.1
MPC_VERSION=1.2.1
ISL_VERSION=0.18
ZSTD_VERSION=1.4.9
BINUTILS_VERSION=2.36
GCC_VERSION=8.4.0
MINGW64_VERSION=8.0.0

download() {
	(
		cd "$SRC_DIR"
		if [ ! -e "gmp-${GMP_VERSION}" ] ; then
			wget https://gmplib.org/download/gmp/gmp-${GMP_VERSION}.tar.lz
			tar --lzip -xvf gmp-${GMP_VERSION}.tar.lz
		fi
		if [ ! -e "mpfr-${MPFR_VERSION}" ]; then
			wget https://www.mpfr.org/mpfr-current/mpfr-${MPFR_VERSION}.tar.xz
			tar xvJf mpfr-${MPFR_VERSION}.tar.xz
		fi
		if [ ! -e "mpc-${MPC_VERSION}" ]; then
			wget https://ftp.gnu.org/gnu/mpc/mpc-${MPC_VERSION}.tar.gz
			tar xvzf mpc-${MPC_VERSION}.tar.gz
		fi
		if [ ! -e "isl-${ISL_VERSION}" ]; then
			wget https://gcc.gnu.org/pub/gcc/infrastructure/isl-${ISL_VERSION}.tar.bz2
			tar xvjf isl-${ISL_VERSION}.tar.bz2
		fi
		if [ ! -e "zstd-${ZSTD_VERSION}" ]; then
			wget https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz
			tar xvzf zstd-${ZSTD_VERSION}.tar.gz
		fi
		if [ ! -e "binutils-${BINUTILS_VERSION}" ]; then
			wget https://mirror.easyname.at/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.xz
			tar xvJf binutils-${BINUTILS_VERSION}.tar.xz
		fi
		if [ ! -e "gcc-${GCC_VERSION}" ]; then
			wget http://mirror.koddos.net/gcc/releases/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz
			tar xvJf gcc-${GCC_VERSION}.tar.xz
		fi
		if [ ! -e "mingw-w64-v${MINGW64_VERSION}" ]; then
			wget https://downloads.sourceforge.net/project/mingw-w64/mingw-w64/mingw-w64-release/mingw-w64-v${MINGW64_VERSION}.tar.bz2
			tar xvjf mingw-w64-v${MINGW64_VERSION}.tar.bz2
		fi
	)
}


build_package() {
	if [ ! -e "$BUILD_DIR/$1.stamp" ]; then
		(
		mkdir  -p "$BUILD_DIR/$1"
		cd "$BUILD_DIR/$1"
		echo "configure $3"
		$2/configure $3
                if [ -z ${4+x} ]; then
                        make -j $(nproc)
                else
                        make -j $(nproc) $4
                fi
                if [ -z ${5+x} ]; then
                        make -j $(nproc) install
                else
                        make -j $(nproc) $5
                fi
		#make install
		) || exit 1
		touch "$BUILD_DIR/$1.stamp" 
	fi
}

build_prereq() {
	build_package gmp "$SRC_DIR/gmp-${GMP_VERSION}" "$HOST_OPTIONS"
	HOST_OPTIONS="$HOST_OPTIONS --with-gmp=$PREFIX"
	build_package mpfr "$SRC_DIR/mpfr-${MPFR_VERSION}" "$HOST_OPTIONS"
	HOST_OPTIONS="$HOST_OPTIONS --with-mpfr=$PREFIX"
	build_package mpc "$SRC_DIR/mpc-${MPC_VERSION}" "$HOST_OPTIONS"
	HOST_OPTIONS="$HOST_OPTIONS --with-mpc=$PREFIX"
	build_package isl "$SRC_DIR/isl-${ISL_VERSION}" "$BASE_OPTIONS --with-gmp-prefix=$PREFIX"
	HOST_OPTIONS="$HOST_OPTIONS --with-isl=$PREFIX"
	# TODO zstd
}

build_gcc() {
	TARGET_OPTIONS="$HOST_OPTIONS --target=x86_64-w64-mingw32 --disable-nls --with-sysroot=$SYSROOT"
	BINUTILS_OPTIONS="$TARGET_OPTIONS --enable-targets=x86_64-w64-mingw32,i686-w64-mingw32"
	build_package binutils "$SRC_DIR/binutils-${BINUTILS_VERSION}" "$BINUTILS_OPTIONS"
	build_package mingw_headers "$SRC_DIR/mingw-w64-v${MINGW64_VERSION}/mingw-w64-headers" "-with-sysroot=$SYSROOT --prefix=$SYSROOT/mingw --host=x86_64-w64-mingw32"
	GCC_OPTIONS="$TARGET_OPTIONS --enable-targets=all --enable-languages=c,c++"
	build_package gcc "$SRC_DIR/gcc-${GCC_VERSION}" "$GCC_OPTIONS" "all-gcc" "install-gcc"
	build_package mingw_crt "$SRC_DIR/mingw-w64-v${MINGW64_VERSION}/mingw-w64-crt" "-with-sysroot=$SYSROOT --prefix=$SYSROOT/mingw --enable-lib32 --enable-lib64 --host=x86_64-w64-mingw32"
	build_package gcc "$SRC_DIR/gcc-${GCC_VERSION}" "$GCC_OPTIONS"
}

SRC_DIR="$(pwd)/sources"
mkdir -p "$SRC_DIR"
mkdir -p workdir
cd workdir
BUILD_DIR="$(pwd)/build"
mkdir -p "$BUILD_DIR"
PREFIX="$(pwd)/prefix"
PATH="$PREFIX/bin:$PATH"
mkdir -p "$PREFIX"
#SYSROOT="$(pwd)/sysroot"
SYSROOT="$PREFIX/sysroot"
mkdir -p "$SYSROOT"
BASE_OPTIONS="--prefix=$PREFIX --disable-shared"
HOST_OPTIONS="$BASE_OPTIONS"

case "$1" in
	"download")
		download
		;;
	"prereq")
		download
		build_prereq
		;;
	"gcc")
		download
		build_prereq
		build_gcc
		;;
	*)
		echo "Unknown option: $1"
		exit 1
		;;
esac

