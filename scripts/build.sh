#!/bin/sh
set -ex

CFG_BUILD="$(gcc -dumpmachine)"
CFG_HOST="x86_64-w64-mingw32"
CFG_TARGET="x86_64-w64-mingw32"

# Package versions
MPFR_VERSION=4.1.0
GMP_VERSION=6.2.1
MPC_VERSION=1.2.1
ISL_VERSION=0.24
ZLIB_VERSION=1.2.11
BINUTILS_VERSION=2.36.1
GCC_VERSION=8.5.0
#GCC_VERSION=9.3.0
#GCC_VERSION=10.3.0
# GCC_VERSION=11.1.0 # Not yet ok.
MINGW64_VERSION=8.0.0
GDB_VERSION=10.2
THREADS="posix"
MULTILIB=true
# Default folders
ROOT_DIR="$(pwd)"
PATCH_DIR="$(pwd)/patches"
SRC_DIR="$(pwd)/sources"
WRK_DIR="$(pwd)/workdir"
WGET="wget --backups=1"
JOBS=$(($(nproc) * 2))
#JOBS=1

version() {
	echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'
}

download() {
	cd "$SRC_DIR"
	if [ ! -e "gmp-${GMP_VERSION}" ]; then
		$WGET https://gmplib.org/download/gmp/gmp-${GMP_VERSION}.tar.lz
		tar --lzip -xf gmp-${GMP_VERSION}.tar.lz
	fi
	if [ ! -e "mpfr-${MPFR_VERSION}" ]; then
		$WGET https://www.mpfr.org/mpfr-current/mpfr-${MPFR_VERSION}.tar.xz
		tar xJf mpfr-${MPFR_VERSION}.tar.xz
	fi
	if [ ! -e "mpc-${MPC_VERSION}" ]; then
		$WGET https://ftp.gnu.org/gnu/mpc/mpc-${MPC_VERSION}.tar.gz
		tar xzf mpc-${MPC_VERSION}.tar.gz
	fi
	if [ ! -e "isl-${ISL_VERSION}" ]; then
		$WGET http://isl.gforge.inria.fr/isl-${ISL_VERSION}.tar.xz
		tar xJf isl-${ISL_VERSION}.tar.xz
	fi
	if [ ! -e "zlib-${ZLIB_VERSION}" ]; then
		$WGET https://zlib.net/zlib-${ZLIB_VERSION}.tar.xz
		tar xJf zlib-${ZLIB_VERSION}.tar.xz
	fi
	if [ ! -e "binutils-${BINUTILS_VERSION}" ]; then
		$WGET https://ftpmirror.gnu.org/binutils/binutils-${BINUTILS_VERSION}.tar.xz
		tar xJf binutils-${BINUTILS_VERSION}.tar.xz
	fi
	if [ ! -e "gcc-${GCC_VERSION}" ]; then
		$WGET https://mirrorservice.org/sites/sourceware.org/pub/gcc/releases/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz
		tar xJf gcc-${GCC_VERSION}.tar.xz
	fi
	if [ ! -e "mingw-w64-v${MINGW64_VERSION}" ]; then
		$WGET https://downloads.sourceforge.net/project/mingw-w64/mingw-w64/mingw-w64-release/mingw-w64-v${MINGW64_VERSION}.tar.bz2
		tar xjf mingw-w64-v${MINGW64_VERSION}.tar.bz2
		if [ "$(version "$GCC_VERSION")" -ge "$(version "11.0.0")" ]; then
			(
				cd "$SRC_DIR/mingw-w64-v${MINGW64_VERSION}"
				# from Liu Hao
				# [Mingw-w64-public] [PATCH] crt: Undefine `__rdtsc` for GCC 11
				patch -p1 <"$PATCH_DIR"/mingw-w64-v8.0.0/0001-crt-Undefine-__rdtsc-for-GCC-11.patch
			)
		fi
	fi
	if [ ! -e "gdb-${GDB_VERSION}" ]; then
		$WGET https://ftp.gnu.org/gnu/gdb/gdb-${GDB_VERSION}.tar.xz
		tar xJf gdb-${GDB_VERSION}.tar.xz
	fi
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
					echo "Make failed for $2"
					exit 1
				}
			else
				make -j "$JOBS" "$4" || {
					echo "Make failed for $2"
					exit 1
				}
			fi
			if [ -z ${5+x} ]; then
				make install || {
					echo "Make install failed for $2"
					exit 1
				}
			else
				make "$5" || {
					echo "Make install failed for $2"
					exit 1
				}
			fi
		) || exit 1
		touch "$BUILD_DIR/$1.stamp"
	fi
}

build_prerequisites() {
	LIBS_OPTIONS="--host=$1 --disable-shared --prefix=$SYSROOT"
	# GMP
	build_package gmp "$SRC_DIR/gmp-${GMP_VERSION}" "$LIBS_OPTIONS"
	# MPFR
	build_package mpfr "$SRC_DIR/mpfr-${MPFR_VERSION}" "$LIBS_OPTIONS --with-gmp=$SYSROOT"
	# MPC
	build_package mpc "$SRC_DIR/mpc-${MPC_VERSION}" "$LIBS_OPTIONS  --with-gmp=$SYSROOT"
	# ISL
	build_package isl "$SRC_DIR/isl-${ISL_VERSION}" "$LIBS_OPTIONS --with-sysroot=$SYSROOT --with-gmp-prefix=$SYSROOT"
}

build_toolchain() {
	figlet "$1" -w 140
	figlet " -> "
	figlet "$2" -w 140
	export BUILD_DIR="$WRK_DIR/$1_build"
	mkdir -p "$BUILD_DIR"
	export SYSROOT="$WRK_DIR/$1_sysroot"
	mkdir -p "$SYSROOT"
	export PREFIX="$WRK_DIR/$1-${GCC_VERSION}"
	mkdir -p "$PREFIX"
	export PATH="$PREFIX/bin:$PATH"
	export LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH"
	# build prerequisites for GCC
	build_prerequisites "$1"
	# Prepare options
	BASE_OPTIONS="--host=$1 --enable-static --with-gmp=$SYSROOT --with-mpfr=$SYSROOT --with-mpc=$SYSROOT --with-isl=$SYSROOT --with-sysroot=$SYSROOT --prefix=$PREFIX --target=$2"
	BINUTILS_OPTIONS="$BASE_OPTIONS --disable-nls"
	GCC_OPTIONS="$BINUTILS_OPTIONS --enable-shared --enable-languages=c,c++ --enable-threads=$THREADS"
	MINGW_CRT_OPTIONS="--with-sysroot=$SYSROOT/$2 --prefix=$PREFIX/$2 --host=$2"
	if [ "$MULTILIB" = true ]; then
		GCC_OPTIONS="$GCC_OPTIONS --enable-targets=all"
		if [ "$2" = "x86_64-w64-mingw32" ]; then
			BINUTILS_OPTIONS="$BINUTILS_OPTIONS --enable-targets=x86_64-w64-mingw32,i686-w64-mingw32"
			MINGW_CRT_OPTIONS="$MINGW_CRT_OPTIONS --enable-lib32"
		fi
	fi
	# MinGW headers
	if [ "$2" = "x86_64-w64-mingw32" ]; then
		build_package mingw_headers "$SRC_DIR/mingw-w64-v${MINGW64_VERSION}/mingw-w64-headers" "-build=$1 --host=$2 --prefix=$PREFIX/$2"
		ln -s -f "$PREFIX/$2" "$SYSROOT/mingw"
		mkdir -p "$SYSROOT/$2/lib"
		ln -s -f "$SYSROOT/$2/lib" "$SYSROOT/$2/lib64"
	fi
	# Binutils
	build_package binutils "$SRC_DIR/binutils-${BINUTILS_VERSION}" "$BINUTILS_OPTIONS"
	# Gcc step 1
	build_package gcc.step1 "$SRC_DIR/gcc-${GCC_VERSION}" "$GCC_OPTIONS" "all-gcc" "install-gcc"
	# MinGW crt
	if [ "$2" = "x86_64-w64-mingw32" ]; then
		build_package mingw_crt "$SRC_DIR/mingw-w64-v${MINGW64_VERSION}/mingw-w64-crt" "$MINGW_CRT_OPTIONS"
		build_package mingw_pthreads "$SRC_DIR/mingw-w64-v${MINGW64_VERSION}/mingw-w64-libraries/winpthreads" "$MINGW_CRT_OPTIONS"
		if [ "$MULTILIB" = true ]; then
			# Build winpthreads for 32bits too!
			export CC="$2-gcc -m32"
			export CCAS="$2-gcc -m32"
			export DLLTOOL="$2-dlltool -m i386"
			export RC="$2-windres -F pe-i386"
			build_package mingw_pthreads_32 "$SRC_DIR/mingw-w64-v${MINGW64_VERSION}/mingw-w64-libraries/winpthreads" "$MINGW_CRT_OPTIONS -prefix=$BUILD_DIR/mingw32"
			unset RC
			unset DLLTOOL
			unset CCAS
			unset CC
			cp -f -a "$BUILD_DIR"/mingw32/lib/* "$PREFIX/$2/lib32/"
			mkdir -p "$PREFIX/lib32/"
			cp -f -a "$BUILD_DIR"/mingw32/bin/*.dll "$PREFIX/lib32/"
		fi
	fi
	# GCC step 2
	build_package gcc.step2 "$SRC_DIR/gcc-${GCC_VERSION}" "$GCC_OPTIONS" "all" "install-strip"
	# Zlib
	(
		if [ ! -e "$BUILD_DIR/zlib_stamp.$1" ]; then
			(
				cd "$SRC_DIR/zlib-${ZLIB_VERSION}"
				make -f win32/Makefile.gcc clean
				make -f win32/Makefile.gcc -j "$JOBS" SHARED_MODE=0 PREFIX="$2"- BINARY_PATH="$PREFIX/$2/bin" INCLUDE_PATH="$PREFIX/$2/include" LIBRARY_PATH="$PREFIX/$2/lib" install
				make -f win32/Makefile.gcc clean
				make -f win32/Makefile.gcc LOC="-m32 -lgcc" RC="$2-windres -F pe-i386" -j "$JOBS" SHARED_MODE=0 PREFIX="$2"- BINARY_PATH="$PREFIX/$2/lib32" INCLUDE_PATH="$PREFIX/$2/include" LIBRARY_PATH="$PREFIX/$2/lib32" install
				touch "$BUILD_DIR/zlib_stamp.$1"
			)
		fi
	)
	build_package gdb "$SRC_DIR/gdb-${GDB_VERSION}" "$BINUTILS_OPTIONS"

}

move_if_exists() {
	if [ -e "$1" ]; then
		mv "$1" "$2"
	fi
}

finalize_x86_64_w64_mingw32() {
	cd "$WRK_DIR"
	move_if_exists "x86_64-w64-mingw32-${GCC_VERSION}"/x86_64-w64-mingw32/bin/libwinpthread-1.dll "x86_64-w64-mingw32-${GCC_VERSION}/bin"
	move_if_exists "x86_64-w64-mingw32-${GCC_VERSION}"/lib/*.dll "x86_64-w64-mingw32-${GCC_VERSION}/bin"
	cp -f x86_64-linux-gnu_build/gcc/x86_64-w64-mingw32/libstdc++-v3/src/.libs/libstdc++-6.dll "x86_64-w64-mingw32-${GCC_VERSION}/bin"
	cp -f x86_64-linux-gnu_build/gcc/x86_64-w64-mingw32/32/libstdc++-v3/src/.libs/libstdc++-6.dll "x86_64-w64-mingw32-${GCC_VERSION}/lib32"
}

test_x86_64_w64_mingw32() {
	export WINEPATH="x86_64-w64-mingw32-${GCC_VERSION}/bin"
	rm -f main.exe main.32.exe

	# Try c in 64 bits
	wine64 "x86_64-w64-mingw32-${GCC_VERSION}"/bin/gcc.exe ../test/main.c -o main.exe -lz
	file main.exe
	wine64 main.exe

	# Try cpp in 64 bits
	wine64 "x86_64-w64-mingw32-${GCC_VERSION}"/bin/g++.exe ../test/main.cpp -o main.exe
	file main.exe
	wine64 main.exe

	# Try c in 32 bits
	wine64 "x86_64-w64-mingw32-${GCC_VERSION}"/bin/gcc.exe ../test/main.c -m32 -o main.exe -lz
	file main.exe
	wine64 main.exe

	# Try cpp in 32 bits
	wine64 "x86_64-w64-mingw32-${GCC_VERSION}"/bin/g++.exe ../test/main.cpp -m32 -o main.32.exe
	file main.32.exe
	export WINEPATH="x86_64-w64-mingw32-${GCC_VERSION}/lib32"
	wine64 main.32.exe
}

create_archive() {

	archive="$ROOT_DIR/release/x86_64-w64-mingw32-${GCC_VERSION}"
	if [ "$MULTILIB" = true ]; then
		archive="${archive}-multilib"
	fi
	archive="${archive}-${THREADS}.7z"
	if [ ! -e "$archive" ]; then
		cd "$WRK_DIR"
		folder="x86_64-w64-mingw32-${GCC_VERSION}"
		cat <<EOF >$folder/config.txt
# Source:
# github.com/13pgeiser
# Architectures
CFG_BUILD=${CFG_BUILD}
CFG_HOST=${CFG_HOST}
CFG_TARGET=${CFG_TARGET}

# Package versions
MPFR_VERSION=${MPFR_VERSION}
GMP_VERSION=${GMP_VERSION}
MPC_VERSION=${MPC_VERSION}
ISL_VERSION=${ISL_VERSION}
ZLIB_VERSION=${ZLIB_VERSION}
BINUTILS_VERSION=${BINUTILS_VERSION}
GCC_VERSION=${GCC_VERSION}
MINGW64_VERSION=${MINGW64_VERSION}
GDB_VERSION=${GDB_VERSION}
THREADS=${THREADS}
MULTILIB=${MULTILIB}
EOF
		mkdir -p "$(dirname "$archive")"
		7za a -t7z -m0=lzma -mx=9 "$archive" "$folder"
	fi
}

# Create work directory
mkdir -p "$WRK_DIR"
cd "$WRK_DIR"

# Download and unpack packages
mkdir -p "$SRC_DIR"
download

figlet "JOBS=$JOBS"

# Build toolchain for build->target
build_toolchain "$CFG_BUILD" "$CFG_TARGET"

# Build toolchain host -> target
if [ "$CFG_BUILD" != "$CFG_HOST" ]; then
	build_toolchain "$CFG_HOST" "$CFG_TARGET"
fi

# Copy dlls
finalize_x86_64_w64_mingw32

# Test
test_x86_64_w64_mingw32

create_archive
exit 0
