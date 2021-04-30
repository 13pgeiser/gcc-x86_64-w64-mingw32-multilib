FROM debian:buster-slim

RUN set -ex \
	&& mkdir -p /usr/local/gcc-ming64

WORKDIR /usr/local/gcc-ming64

RUN set -ex \
	&& apt-get update \
	&& apt-get dist-upgrade -y \
	&& apt-get install -y --no-install-recommends \
		autoconf \
		automake \
		bison \
		build-essential \
		bzip2 \
		ca-certificates \
		curl \
		flex \
		git \
		gzip \
		lzip \
		wget \
		xz-utils \
	&& apt-get clean \
	&& rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

# VERSIONS

ARG MPFR_VERSION=4.1.0
ARG GMP_VERSION=6.2.1
ARG MPC_VERSION=1.2.1
ARG ISL_VERSION=0.18
ARG ZSTD_VERSION=1.4.9
ARG BINUTILS_VERSION=2.36
ARG GCC_VERSION=8.4.0

# MPFR

RUN set -ex \
	&& wget https://www.mpfr.org/mpfr-current/mpfr-${MPFR_VERSION}.tar.xz \
	&& tar xvJf mpfr-${MPFR_VERSION}.tar.xz

# GMP

RUN set -ex \
	&& wget https://gmplib.org/download/gmp/gmp-${GMP_VERSION}.tar.lz \
	&& tar --lzip -xvf gmp-${GMP_VERSION}.tar.lz

# MPC

RUN set -ex \
	&& wget https://ftp.gnu.org/gnu/mpc/mpc-${MPC_VERSION}.tar.gz \
	&& tar xvzf mpc-${MPC_VERSION}.tar.gz

# ISL

RUN set -ex \
	&& wget https://gcc.gnu.org/pub/gcc/infrastructure/isl-${ISL_VERSION}.tar.bz2 \
	&& tar xvjf isl-${ISL_VERSION}.tar.bz2

# ZSTD

RUN set -ex \
	&& wget https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz \
	&& tar xvzf zstd-${ZSTD_VERSION}.tar.gz

# Binutils

RUN set -ex \
	&& wget https://mirror.easyname.at/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.xz \
	&& tar xvJf binutils-${BINUTILS_VERSION}.tar.xz

# GCC

RUN set -ex \
	&& wget http://mirror.koddos.net/gcc/releases/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz \
	&& tar xvJf gcc-${GCC_VERSION}.tar.xz 

RUN set -ex \
	&& ls -al

