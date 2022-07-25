#!/bin/bash
set -ex

# Package versions
MPFR_VERSION=4.1.0
GMP_VERSION=6.2.1
MPC_VERSION=1.2.1
ISL_VERSION=0.25
ZLIB_VERSION=1.2.12
#ZSTD_VERSION=1.5.2
BINUTILS_VERSION=2.38
GCC_VERSION=8.5.0
GCC_VERSION=9.5.0
GCC_VERSION=10.4.0
GCC_VERSION=11.3.0
#GCC_VERSION=12.1.0
MINGW64_VERSION=9.0.0
#MINGW64_VERSION=10.0.0 # Not yet working.
GDB_VERSION=10.2
GDB_VERSION=12.1
EXPAT_VERSION=2.4.8
NEWLIB_VERSION=4.2.0.20211231
#GLIBC_VERSION=2.31
GLIBC_VERSION=2.35
# Default folders
ROOT_DIR="$(pwd)"
PATCH_DIR="$(pwd)/patches"
SRC_DIR="$(pwd)/sources"
WRK_DIR="$(pwd)/workdir"
DOWNLOAD="curl  -O -J -L --retry 20"
JOBS=$(($(nproc) * 2))
#JOBS=1

download() {
	cd "$SRC_DIR"
	if [ ! -e "gmp-${GMP_VERSION}" ]; then
		$DOWNLOAD https://gmplib.org/download/gmp/gmp-${GMP_VERSION}.tar.lz
		tar --lzip -xf "gmp-${GMP_VERSION}.tar.lz"
	fi
	if [ ! -e "mpfr-${MPFR_VERSION}" ]; then
		$DOWNLOAD https://www.mpfr.org/mpfr-current/mpfr-${MPFR_VERSION}.tar.xz
		tar xJf "mpfr-${MPFR_VERSION}.tar.xz"
	fi
	if [ ! -e "mpc-${MPC_VERSION}" ]; then
		$DOWNLOAD https://ftp.gnu.org/gnu/mpc/mpc-${MPC_VERSION}.tar.gz
		tar xzf "mpc-${MPC_VERSION}.tar.gz"
	fi
	if [ ! -e "isl-${ISL_VERSION}" ]; then
		#$DOWNLOAD http://isl.gforge.inria.fr/isl-${ISL_VERSION}.tar.xz
		$DOWNLOAD https://mirrors.slackware.com/slackware/slackware64-current/source/l/isl/isl-${ISL_VERSION}.tar.xz
		tar xJf "isl-${ISL_VERSION}.tar.xz"
	fi
	if [ ! -e "zlib-${ZLIB_VERSION}" ]; then
		$DOWNLOAD https://zlib.net/zlib-${ZLIB_VERSION}.tar.xz
		tar xJf "zlib-${ZLIB_VERSION}.tar.xz"
	fi
	#~ if [ ! -e "zstd-${ZSTD_VERSION}" ]; then
	#~ $DOWNLOAD https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz
	#~ tar xzf "zstd-${ZSTD_VERSION}.tar.gz"
	#~ fi
	if [ ! -e "binutils-${BINUTILS_VERSION}" ]; then
		$DOWNLOAD http://ftpmirror.gnu.org/binutils/binutils-${BINUTILS_VERSION}.tar.xz
		tar xJf "binutils-${BINUTILS_VERSION}.tar.xz"
		if [ "$BINUTILS_VERSION" = "2.38" ]; then
			(
				cd binutils-${BINUTILS_VERSION}
				patch -p1 <"$PATCH_DIR/binutils-gdb-d65c0ddddd85645cab6f11fd711d21638a74489f.patch"
				patch -p1 <"$PATCH_DIR/binutils-gdb-95086e1e54a726a0d7671d70640bc76e4fddf198.patch"
			)
		fi
	fi
	if [ ! -e "gcc-${GCC_VERSION}" ]; then
		$DOWNLOAD http://ftpmirror.gnu.org/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz
		tar xJf "gcc-${GCC_VERSION}.tar.xz"
	fi

	if [ ! -e "gdb-${GDB_VERSION}" ]; then
		$DOWNLOAD http://ftpmirror.gnu.org/gdb/gdb-${GDB_VERSION}.tar.xz
		tar xJf "gdb-${GDB_VERSION}.tar.xz"
	fi
	if [ ! -e "expat-${EXPAT_VERSION}" ]; then
		$DOWNLOAD "https://github.com/libexpat/libexpat/releases/download/R_${EXPAT_VERSION//./_}/expat-${EXPAT_VERSION}.tar.xz"
		tar xJf "expat-${EXPAT_VERSION}.tar.xz"
	fi

}

download_mingw() {
	(
		cd "$SRC_DIR"
		if [ ! -e "mingw-w64-v${MINGW64_VERSION}" ]; then
			$DOWNLOAD https://downloads.sourceforge.net/project/mingw-w64/mingw-w64/mingw-w64-release/mingw-w64-v${MINGW64_VERSION}.tar.bz2
			tar xjf "mingw-w64-v${MINGW64_VERSION}.tar.bz2"
		fi
	)
}

download_newlib() {
	(
		cd "$SRC_DIR"
		if [ ! -e "newlib-${NEWLIB_VERSION}" ]; then
			$DOWNLOAD "ftp://sourceware.org/pub/newlib/newlib-${NEWLIB_VERSION}.tar.gz"
			tar xzf "newlib-${NEWLIB_VERSION}.tar.gz"
		fi
	)
}

download_glibc() {
	(
		cd "$SRC_DIR"
		if [ ! -e "glibc-${GLIBC_VERSION}" ]; then
			$DOWNLOAD "http://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VERSION}.tar.xz"
			tar xJf "glibc-${GLIBC_VERSION}.tar.xz"
		fi
	)
}

build_package() {
	if [ ! -e "$BUILD_DIR/$1.stamp" ]; then
		(
			mkdir -p "$BUILD_DIR/${1%%.*}"
			cd "$BUILD_DIR/${1%%.*}"
			if [[ "$3" != "skip" ]]; then
				if [ ! -e ".configured_${1##*.}" ]; then
					echo "configure $3"
					# shellcheck disable=SC2086
					"$2"/configure $3 || {
						echo "Configure failed for $2"
						exit 1
					}
					touch ".configured_${1##*.}"
				fi
			fi
			if [[ "$4" != "skip" ]]; then
				if [ -z ${4+x} ]; then
					make -j "$JOBS" || {
						echo "Make failed for $2"
						exit 1
					}
				else
					# shellcheck disable=SC2086
					make -j "$JOBS" $4 || {
						echo "Make failed for $2"
						exit 1
					}
				fi
			fi
			if [[ "$5" != "skip" ]]; then
				if [ -z ${5+x} ]; then
					make install || {
						echo "Make install failed for $2"
						exit 1
					}
				else
					# shellcheck disable=SC2086
					make $5 || {
						echo "Make install failed for $2"
						exit 1
					}
				fi
			fi
		) || exit 1
		touch "$BUILD_DIR/$1.stamp"
	fi
}

build_prerequisites() {
	LIBS_OPTIONS="--host=$1 --disable-shared --prefix=$SYSROOT"
	# GMP
	build_package gmp "$SRC_DIR/gmp-${GMP_VERSION}" "$LIBS_OPTIONS"
	build_package gmp_prefix "$SRC_DIR/gmp-${GMP_VERSION}" "--host=$1 --disable-shared --prefix=$PREFIX"
	# MPFR
	build_package mpfr "$SRC_DIR/mpfr-${MPFR_VERSION}" "$LIBS_OPTIONS --with-gmp=$SYSROOT"
	# MPC
	build_package mpc "$SRC_DIR/mpc-${MPC_VERSION}" "$LIBS_OPTIONS  --with-gmp=$SYSROOT"
	# ISL
	build_package isl "$SRC_DIR/isl-${ISL_VERSION}" "$LIBS_OPTIONS --with-sysroot=$SYSROOT --with-gmp-prefix=$SYSROOT"
	# Zlib
	if [ ! -e "$BUILD_DIR/zlib_stamp.$1" ]; then
		(
			if [ "$1" = "x86_64-w64-mingw32" ]; then
				cd "$SRC_DIR/zlib-${ZLIB_VERSION}"
				cp -f zconf.h.in zconf.h
				make -f win32/Makefile.gcc clean
				make -f win32/Makefile.gcc -j "$JOBS" SHARED_MODE=0 PREFIX="$1"- BINARY_PATH="$PREFIX/$1/bin" INCLUDE_PATH="$PREFIX/$1/include" LIBRARY_PATH="$PREFIX/$1/lib" install
				make -f win32/Makefile.gcc clean
				make -f win32/Makefile.gcc LOC="-m32 -lgcc" RC="$1-windres -F pe-i386" -j "$JOBS" SHARED_MODE=0 PREFIX="$1"- BINARY_PATH="$PREFIX/$1/lib32" INCLUDE_PATH="$PREFIX/$1/include" LIBRARY_PATH="$PREFIX/$1/lib32" install
			else
				mkdir -p "$BUILD_DIR/zlib"
				cd "$BUILD_DIR/zlib"
				cmake "$SRC_DIR/zlib-${ZLIB_VERSION}" -DCMAKE_INSTALL_PREFIX="$SYSROOT"
				make -j "$JOBS"
				make install
			fi
		)
		touch "$BUILD_DIR/zlib_stamp.$1"
	fi
}

build_toolchain() {
	figlet "$1" -w 140
	figlet " -> "
	figlet "$2" -w 140
	export BUILD_DIR="$WRK_DIR/$1_$2_build"
	mkdir -p "$BUILD_DIR"
	export SYSROOT="$WRK_DIR/$1_$2_sysroot"
	mkdir -p "$SYSROOT"
	export PREFIX="$WRK_DIR/$1_$2-${GCC_VERSION}"
	mkdir -p "$PREFIX"
	export PATH="$PREFIX/bin:$PATH"
	build_prerequisites "$1"
	BASE_NO_SYSROOT_OPTIONS="--host=$1 --disable-nls --enable-static --with-gmp=$SYSROOT --with-mpfr=$SYSROOT --with-mpc=$SYSROOT --with-isl=$SYSROOT --prefix=$PREFIX --target=$2"
	BASE_OPTIONS="$BASE_NO_SYSROOT_OPTIONS --with-sysroot=$SYSROOT"
	NEWLIB_OPTIONS="$BASE_OPTIONS --disable-newlib-supplied-syscalls --enable-newlib-io-long-long --enable-newlib-io-c99-formats --enable-newlib-mb --enable-newlib-reent-check-verify"
	NEWLIB_NANO_OPTIONS="$BASE_OPTIONS --prefix=$SYSROOT/nano --disable-newlib-supplied-syscalls --enable-newlib-nano-malloc --disable-newlib-unbuf-stream-opt --enable-newlib-reent-small --disable-newlib-fseek-optimization --enable-newlib-nano-formatted-io --disable-newlib-fvwrite-in-streamio --disable-newlib-wide-orient --enable-lite-exit --enable-newlib-global-atexit --enable-newlib-reent-check-verify"
	case "$2" in
	"x86_64-w64-mingw32")
		BINUTILS_OPTIONS="$BASE_OPTIONS --enable-targets=x86_64-w64-mingw32,i686-w64-mingw32"
		MINGW_CRT_OPTIONS="--with-sysroot=$SYSROOT/$2 --prefix=$PREFIX/$2 --host=$2 --enable-lib32"
		GCC_OPTIONS="$BASE_OPTIONS --enable-checking=release --enable-shared --enable-languages=c,c++,fortran,lto,objc --enable-threads=posix"
		LIBC="mingw"
		;;
	"arm-none-eabi")
		BINUTILS_OPTIONS="$BASE_OPTIONS --enable-initfini-array"
		GCC_OPTIONS="$BASE_OPTIONS --enable-checking=release --disable-shared --enable-languages=c,c++,lto --with-newlib --disable-threads --disable-tls --with-multilib-list=aprofile,rmprofile"
		LIBC="newlib"
		;;
	"riscv32-unknown-elf" | "moxie-elf" | "m68k-elf" | "arc-elf")
		BINUTILS_OPTIONS="$BASE_OPTIONS --enable-initfini-array"
		GCC_OPTIONS="$BASE_OPTIONS --enable-checking=release --disable-shared --enable-languages=c,c++,lto --with-newlib --disable-threads --disable-tls"
		LIBC="newlib"
		;;
	"x86_64-linux-gnu")
		if [ "$1" != "$2" ]; then
			echo "Not supported $1 -> $2"
			exit 1
		fi
		BASE_OPTIONS="$BASE_NO_SYSROOT_OPTIONS --enable-shared --enable-multiarch --disable-werror --with-arch-32=i686 --with-abi=m64 --with-multilib-list=m32,m64 --enable-multilib --with-tune=generic"
		BINUTILS_OPTIONS="$BASE_OPTIONS"
		GCC_OPTIONS="$BASE_OPTIONS --enable-checking=release --enable-languages=c,c++ --enable-shared --enable-threads=posix --enable-libstdcxx-debug --enable-libstdcxx-time=yes --with-default-libstdcxx-abi=new --enable-gnu-unique-object --disable-vtable-verify --enable-plugin --enable-default-pie --with-system-zlib"
		GLIBC_OPTIONS=""
		unset LIBC
		#BASE_OPTIONS="$BASE_NO_SYSROOT_OPTIONS --enable-shared --enable-multiarch --disable-werror --with-arch-32=i686 --with-abi=m64 --with-multilib-list=m32,m64 --enable-multilib --with-tune=generic --with-sysroot=$SYSROOT"
		#BINUTILS_OPTIONS="$BASE_OPTIONS"
		#GCC_OPTIONS="$BASE_OPTIONS --enable-checking=release --enable-languages=c,c++ --enable-shared --enable-threads --with-glibc-version=$GLIBC_VERSION"
		#~ GLIBC_OPTIONS="$BASE_OPTIONS --with-headers=$SYSROOT/usr/include/ --prefix=$PREFIX"
		#~ mkdir -p "$SYSROOT/usr/include"
		#~ cp -afLr /usr/include/asm "$SYSROOT/usr/include/"
		#~ cp -afLr /usr/include/asm-generic "$SYSROOT/usr/include/"
		#~ cp -afLr /usr/include/linux "$SYSROOT/usr/include/"
		#~ cp -afLr /usr/include/selinux "$SYSROOT/usr/include/"
		#~ LIBC="glibc"
		;;
	*)
		echo "Unsupported architecture $2"
		exit 1
		;;
	esac
	if [ -n "${LIBC}" ]; then
		"download_${LIBC}"
	fi
	case "$LIBC" in
	"mingw")
		build_package mingw_headers "$SRC_DIR/mingw-w64-v${MINGW64_VERSION}/mingw-w64-headers" "-build=$1 --host=$2 --prefix=$PREFIX/$2"
		ln -s -f "$PREFIX/$2" "$SYSROOT/mingw"
		mkdir -p "$SYSROOT/$2/lib"
		ln -s -f "$SYSROOT/$2/lib" "$SYSROOT/$2/lib64"
		;;
	esac
	# Binutils
	build_package binutils "$SRC_DIR/binutils-${BINUTILS_VERSION}" "$BINUTILS_OPTIONS"
	# GCC bootstrap
	if [ -n "${LIBC}" ]; then
		build_package gcc.boostrap "$SRC_DIR/gcc-${GCC_VERSION}" "$GCC_OPTIONS $GCC_OPTIONS_BOOTSTRAP" "all-gcc" "install-gcc"
	fi
	# MinGW crt
	case "$LIBC" in
	"mingw")
		build_package mingw_crt "$SRC_DIR/mingw-w64-v${MINGW64_VERSION}/mingw-w64-crt" "$MINGW_CRT_OPTIONS"
		build_package mingw_pthreads "$SRC_DIR/mingw-w64-v${MINGW64_VERSION}/mingw-w64-libraries/winpthreads" "$MINGW_CRT_OPTIONS"
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
		;;
	"newlib")
		build_package newlib "$SRC_DIR/newlib-${NEWLIB_VERSION}" "$NEWLIB_OPTIONS"
		build_package newlib_nano "$SRC_DIR/newlib-${NEWLIB_VERSION}" "$NEWLIB_NANO_OPTIONS"
		(
			cd "$SYSROOT/nano"
			while IFS= read -r -d '' src_lib; do
				dst_lib="$PREFIX/${src_lib::-2}_nano.a"
				if [ ! -e "$dst_lib" ]; then
					cp "$src_lib" "$dst_lib"
				fi
			done < <(find . -name '*.a' -print0)
			mkdir -p "$PREFIX/include/newlib-nano"
			cp -f "$SYSROOT/nano/$2/include/newlib.h" "$PREFIX/include/newlib-nano"
		)
		;;
	"glibc")
		build_package glibcheaders "$SRC_DIR/glibc-${GLIBC_VERSION}" "$GLIBC_OPTIONS --prefix=$SYSROOT/usr" "skip" "install-bootstrap-headers=yes install-headers"
		touch "$SYSROOT/usr/include/gnu/stubs.h"
		build_package glibc64.sub "$SRC_DIR/glibc-${GLIBC_VERSION}" "$GLIBC_OPTIONS" "csu/subdir_lib" "skip"
		(
			cd "$BUILD_DIR/glibc64"
			mkdir -p "$PREFIX/$2/lib/$2"
			install csu/crt1.o csu/crti.o csu/crtn.o "$PREFIX/$2/lib/$2"
			if [ ! -e "$PREFIX/$2/lib/$2/libc.so" ]; then
				"$2-gcc" -nostdlib -nostartfiles -shared -x c /dev/null -o "$PREFIX/$2/lib/$2/libc.so"
			fi
		)
		export CC="$2-gcc -m32"
		export CXX="$2-g++ -m32"
		build_package glibc32.sub "$SRC_DIR/glibc-${GLIBC_VERSION}" "$GLIBC_OPTIONS --host=i686-linux-gnu" "csu/subdir_lib" "skip"
		(
			cd "$BUILD_DIR/glibc32"
			mkdir -p "$PREFIX/$2/lib/"
			install csu/crt1.o csu/crti.o csu/crtn.o "$PREFIX/$2/lib/"
			if [ ! -e "$PREFIX/$2/lib/libc.so" ]; then
				$CC -nostdlib -nostartfiles -shared -x c /dev/null -o "$PREFIX/$2/lib/libc.so"
			fi
		)
		unset CXX
		unset CC
		build_package gcc.libgcc "$SRC_DIR/gcc-${GCC_VERSION}" "skip" "all-target-libgcc" "install-target-libgcc"
		build_package glibc64 "$SRC_DIR/glibc-${GLIBC_VERSION}" "skip"
		;;
	esac
	# GCC final
	build_package gcc.final "$SRC_DIR/gcc-${GCC_VERSION}" "$GCC_OPTIONS $GCC_OPTIONS_FINAL" "all" "install-strip"
	if [ "$1" = "x86_64-w64-mingw32" ]; then
		export LOADLIBES="-lbcrypt"
	fi
	build_package expat "$SRC_DIR/expat-${EXPAT_VERSION}" "$BINUTILS_OPTIONS"
	build_package gdb "$SRC_DIR/gdb-${GDB_VERSION}" "$BINUTILS_OPTIONS"
	unset LOADLIBES
}

move_if_exists() {
	if [ -e "$1" ]; then
		mv "$1" "$2"
	fi
}

finalize_x86_64_w64_mingw32() {
	cd "$WRK_DIR"
	move_if_exists "$1_$2-${GCC_VERSION}/x86_64-w64-mingw32/bin/libwinpthread-1.dll" "$1_$2-${GCC_VERSION}/bin"
	move_if_exists "$1_$2-${GCC_VERSION}/lib/"*.dll "$1_$2-${GCC_VERSION}/bin"
	cp -f "$1_$2_build/gcc/$2/libstdc++-v3/src/.libs/libstdc++-6.dll" "$1_$2-${GCC_VERSION}/bin"
	cp -f "$1_$2_build/gcc/$2/32/libstdc++-v3/src/.libs/libstdc++-6.dll" "$1_$2-${GCC_VERSION}/lib32"
}

test_x86_64_w64_mingw32() {
	cd "$WRK_DIR"
	rm -f main.exe main.32.exe

	# Try c in 64 bits
	export WINEPATH="$1_$2-${GCC_VERSION}/bin"
	wine64 "$1_$2-${GCC_VERSION}/bin/gcc.exe" ../test/main.c -o main.exe -lz
	file main.exe
	wine64 main.exe

	# Try c++ in 64 bits
	wine64 "$1_$2-${GCC_VERSION}/bin/g++.exe" ../test/main.cpp -o main.exe
	file main.exe
	wine64 main.exe

	# Try c in 32 bits
	wine64 "$1_$2-${GCC_VERSION}/bin/gcc.exe" ../test/main.c -m32 -o main.exe -lz
	file main.exe
	wine64 main.exe

	# Try c++ in 32 bits
	wine64 "$1_$2-${GCC_VERSION}/bin/g++.exe" ../test/main.cpp -m32 -o main.32.exe
	file main.32.exe
	export WINEPATH="$1_$2-${GCC_VERSION}/lib32"
	wine64 main.32.exe

	# Check gdb
	wine64 "$1_$2-${GCC_VERSION}"/bin/gdb.exe --version

	# Done.
	rm -f main.exe main.32.exe
}

create_archive() {
	archive="$ROOT_DIR/release/$1_$2-${GCC_VERSION}.7z"
	if [ ! -e "$archive" ]; then
		cd "$WRK_DIR"
		folder="$1_$2-${GCC_VERSION}"
		cat <<EOF >"$folder/config.txt"
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
EOF
		mkdir -p "$(dirname "$archive")"
		7za a -t7z -m0=lzma -mx=9 "$archive" "$folder"
	fi
}

build_full_toolchain() {
	# Create work directory
	mkdir -p "$WRK_DIR"
	cd "$WRK_DIR"

	# Download and unpack packages
	mkdir -p "$SRC_DIR"
	download

	figlet "JOBS=$JOBS"

	CFG_BUILD="$(gcc -dumpmachine)"
	CFG_HOST="$1"
	CFG_TARGET="$2"

	# Build toolchain host -> target
	if [ "$CFG_BUILD" != "$CFG_HOST" ]; then
		build_toolchain "$CFG_BUILD" "$CFG_TARGET"
		build_toolchain "$CFG_BUILD" "$CFG_HOST"
		build_toolchain "$CFG_HOST" "$CFG_TARGET"
	else
		build_toolchain "$CFG_HOST" "$CFG_TARGET"
	fi

	if [ "$CFG_TARGET" = "x86_64-w64-mingw32" ]; then
		# Copy dlls
		finalize_x86_64_w64_mingw32 "$CFG_HOST" "$CFG_TARGET"

		# Test
		if [ "$CFG_HOST" = "x86_64-w64-mingw32" ]; then
			test_x86_64_w64_mingw32 "$CFG_HOST" "$CFG_TARGET"
		fi
	fi

	create_archive "$CFG_HOST" "$CFG_TARGET"
}

build_full_toolchain "$(gcc -dumpmachine)" "x86_64-w64-mingw32"
build_full_toolchain "x86_64-w64-mingw32" "x86_64-w64-mingw32"

#~ build_full_toolchain "$(gcc -dumpmachine)" "moxie-elf"
#~ build_full_toolchain "x86_64-w64-mingw32" "moxie-elf"

#~ build_full_toolchain "$(gcc -dumpmachine)" "riscv32-unknown-elf"
#~ build_full_toolchain "x86_64-w64-mingw32" "riscv32-unknown-elf"

#~ build_full_toolchain "$(gcc -dumpmachine)" "m68k-elf"
#~ build_full_toolchain "x86_64-w64-mingw32" "m68k-elf"

#~ build_full_toolchain "$(gcc -dumpmachine)" "arc-elf"
#~ build_full_toolchain "x86_64-w64-mingw32" "arc-elf"

#~ build_full_toolchain "$(gcc -dumpmachine)" "arm-none-eabi"
#~ build_full_toolchain "x86_64-w64-mingw32" "arm-none-eabi"

#~ build_full_toolchain "$(gcc -dumpmachine)" "$(gcc -dumpmachine)"

exit 0
