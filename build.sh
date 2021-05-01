#!/bin/sh
set -ex

CFG_BUILD="$(gcc -dumpmachine)"
CFG_HOST="x86_64-w64-mingw32"
CFG_TARGET="x86_64-w64-mingw32"

# Package versions
MPFR_VERSION=4.1.0
GMP_VERSION=6.2.1
MPC_VERSION=1.2.1
ISL_VERSION=0.18
ZSTD_VERSION=1.4.9
BINUTILS_VERSION=2.36
GCC_VERSION=8.4.0
#GCC_VERSION=10.3.0
MINGW64_VERSION=7.0.0
GDB_VERSION=10.2

# Default folders
SRC_DIR="$(pwd)/sources"
WRK_DIR="$(pwd)/workdir"
JOBS="$(nproc)"
#JOBS=1

download() {
	(
		cd "$SRC_DIR"
		if [ ! -e "gmp-${GMP_VERSION}" ]; then
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
		if [ ! -e "gdb-${GDB_VERSION}" ]; then
			wget https://ftp.gnu.org/gnu/gdb/gdb-${GDB_VERSION}.tar.xz
			tar xvJf gdb-${GDB_VERSION}.tar.xz
		fi
	)
}

build_package() {
	if [ ! -e "$BUILD_DIR/$1.stamp" ]; then
		(
			mkdir -p "$BUILD_DIR/${1%%.*}"
			cd "$BUILD_DIR/${1%%.*}"
			if [ ! -e .configured ]; then
				echo "configure $3"
				# shellcheck disable=SC2086
				"$2"/configure $3 || {
					echo "Configure failed for $2"
					exit 1
				}
				touch .configured
			fi
			if [ -z ${4+x} ]; then
				make -j "$JOBS" || {
					echo "Configure failed for $2"
					exit 1
				}
			else
				make -j "$JOBS" "$4" || {
					echo "Configure failed for $2"
					exit 1
				}
			fi
			if [ -z ${5+x} ]; then
				make install || {
					echo "Configure failed for $2"
					exit 1
				}
			else
				make "$5" || {
					echo "Configure failed for $2"
					exit 1
				}
			fi
		) || exit 1
		touch "$BUILD_DIR/$1.stamp"
	fi
}

build_toolchain() {
	BUILD_DIR="$WRK_DIR/$1_build"
	CROSS_DIR="$WRK_DIR/$1_cross"
	SYSROOT="$WRK_DIR/$1-${GCC_VERSION}"
	mkdir -p "$BUILD_DIR"
	mkdir -p "$CROSS_DIR"
	mkdir -p "$SYSROOT"
	PATH="$SYSROOT/bin:$PATH"
	BASE_OPTIONS="--disable-shared --host=$1"
	HOST_OPTIONS="$BASE_OPTIONS"
	build_package gmp "$SRC_DIR/gmp-${GMP_VERSION}" "$HOST_OPTIONS --prefix=$CROSS_DIR"
	HOST_OPTIONS="$HOST_OPTIONS --with-gmp=$CROSS_DIR"
	build_package mpfr "$SRC_DIR/mpfr-${MPFR_VERSION}" "$HOST_OPTIONS --prefix=$CROSS_DIR"
	HOST_OPTIONS="$HOST_OPTIONS --with-mpfr=$CROSS_DIR"
	build_package mpc "$SRC_DIR/mpc-${MPC_VERSION}" "$HOST_OPTIONS --prefix=$CROSS_DIR"
	HOST_OPTIONS="$HOST_OPTIONS --with-mpc=$CROSS_DIR"
	build_package isl "$SRC_DIR/isl-${ISL_VERSION}" "$BASE_OPTIONS --prefix=$CROSS_DIR --with-gmp-prefix=$CROSS_DIR"
	HOST_OPTIONS="$HOST_OPTIONS --with-isl=$CROSS_DIR"
	TARGET_OPTIONS="$HOST_OPTIONS --target=$2 --disable-nls --with-sysroot=$SYSROOT --prefix=$SYSROOT"
	if [ "$2" = "x86_64-w64-mingw32" ]; then
		BINUTILS_OPTIONS="$TARGET_OPTIONS --enable-targets=x86_64-w64-mingw32,i686-w64-mingw32"
	fi
	build_package binutils "$SRC_DIR/binutils-${BINUTILS_VERSION}" "$BINUTILS_OPTIONS"
	case $CFG_TARGET in
	*"mingw32"*)
		build_package mingw_headers "$SRC_DIR/mingw-w64-v${MINGW64_VERSION}/mingw-w64-headers" "-with-sysroot=$SYSROOT --prefix=$SYSROOT/mingw --host=$2"
		;;
	esac
	GCC_OPTIONS="$TARGET_OPTIONS --enable-targets=all --enable-languages=c,c++"
	#if [ "$1" = "$2" ]; then
	#	GCC_OPTIONS="$GCC_OPTIONS --enable-threads=posix"
	#fi
	build_package gcc.step1 "$SRC_DIR/gcc-${GCC_VERSION}" "$GCC_OPTIONS" "all-gcc" "install-gcc"
	case $CFG_TARGET in
	*"mingw32"*)
		build_package mingw_crt "$SRC_DIR/mingw-w64-v${MINGW64_VERSION}" "$HOST_OPTIONS -with-sysroot=$SYSROOT --prefix=$SYSROOT/mingw --enable-lib32 --enable-lib64 --host=$2 --with-libraries=winpthreads"
		;;
	esac
	build_package gcc.step2 "$SRC_DIR/gcc-${GCC_VERSION}" "$GCC_OPTIONS"
	if [ "$1" = "$2" ]; then
		echo "GDB"
		#		build_package gdb "$SRC_DIR/gdb-${GDB_VERSION}" "$BASE_OPTIONS -prefix=$SYSROOT"
	fi
}

# Create work directory
mkdir -p "$WRK_DIR"
cd "$WRK_DIR"

# Download and unpack packages
mkdir -p "$SRC_DIR"
download

# Build toolchain for build->target
build_toolchain "$CFG_BUILD" "$CFG_TARGET"

# Build toolchain host -> target
if [ "$CFG_BUILD" != "$CFG_HOST" ]; then
	build_toolchain "$CFG_HOST" "$CFG_TARGET"
fi
