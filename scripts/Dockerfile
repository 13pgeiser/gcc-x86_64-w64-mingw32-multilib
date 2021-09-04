FROM debian:bullseye-slim

RUN set -ex \
	&& apt-get update \
	&& apt-get dist-upgrade -y \
	&& apt-get install -y \
		autoconf \
		automake \
		bison \
		build-essential \
		bzip2 \
		ca-certificates \
		curl \
		figlet \
		file \
		flex \
		git \
		gzip \
		lzip \
		p7zip-full \
		texinfo \
		wget \
		xz-utils \
	&& apt-get clean \
	&& rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

RUN set -ex \
	&& dpkg --add-architecture i386 \
	&& apt-get update \
	&& apt-get install -y \
		wine32 \
		wine64 \
	&& apt-get clean \
	&& rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*
