FROM debian:trixie-slim AS builder

ARG BORINGSSL_COMMIT_ID="HEAD~0"
ARG BUILD_SHARED_LIBS="1"

RUN set -eux; \
	apt-get update; \
	DEBIAN_FRONTEND=noninteractive \
	apt-get install -y --no-install-recommends \
		tzdata \
		ca-certificates \
		lsb-release \
		gnupg \
		tree \
		git \
		wget \
		curl \
		make \
		cmake \
		ninja-build \
		meson \
		libtool \
		bash \
		7zip \
		unzip \
		pkg-config \
		build-essential \
		libzstd-dev \
		zlib1g-dev \
		libpcre2-dev \
		; \
	rm -rf /var/lib/apt/lists/*; \
	mkdir -p /usr/src;

#################################################################################################

### 安装 Clang 22
RUN set -eux; \
	mkdir -p /opt/clang; \
	cd /opt/clang; \
    wget -qO llvm.sh https://apt.llvm.org/llvm.sh; \
    chmod +x llvm.sh; \
    ./llvm.sh 22 all; \
	# 创建符号链接，以便 CMake 能找到 clang/clang++
    ln -sf /usr/bin/clang-22 /usr/local/bin/clang; \
    ln -sf /usr/bin/clang++-22 /usr/local/bin/clang++; \
	ln -sf /usr/bin/lld-22 /usr/local/bin/lld;

ENV CC=clang
ENV CXX=clang++

#################################################################################################

# CMAKE_BUILD_TYPE: Debug, Release, RelWithDebInfo, MinSizeRel
# -j$(getconf _NPROCESSORS_ONLN) | -j"$(nproc)"
RUN set -eux; \
	# git clone https://boringssl.googlesource.com/boringssl /usr/src/boringssl; \
	git clone --recurse-submodules https://github.com/google/boringssl /usr/src/boringssl; \
	cd /usr/src/boringssl; \
	git checkout --force --quiet ${BORINGSSL_COMMIT_ID}; \
	git submodule update --init --recursive; \
	mkdir -p /usr/src/boringssl/build; \
	cmake -B/usr/src/boringssl/build -S/usr/src/boringssl \
		-DCMAKE_BUILD_TYPE=Release \
		-DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS} \
		-DCMAKE_C_COMPILER=clang \
    	-DCMAKE_CXX_COMPILER=clang++ \
		-DCMAKE_C_FLAGS="-O2 -fPIC" \
		-DCMAKE_CXX_FLAGS="-O2 -fPIC" \
		-GNinja; \
	# (二选一)
	ninja -C /usr/src/boringssl/build;
	#cmake --build /usr/src/boringssl/build --parallel $(nproc);

# 复制 BoringSSL 头文件和静态库到标准路径
RUN set -eux; \
	mkdir -p /usr/boringssl/include /usr/boringssl/lib; \
	cp -r /usr/src/boringssl/include/openssl /usr/boringssl/include/openssl; \
	cp -r /usr/src/boringssl/build/* /usr/boringssl/lib; \
	ls /usr/boringssl/lib;

# clean
RUN set -eux; \
	rm -rf /tmp/* /usr/src;

ENV LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:/usr/boringssl/lib"

ENV TZ=Asia/Shanghai
ENV LC_TIME=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

LABEL \
	description="Optimized BoringSSL with Clang(22)" \
	maintainer="Custom Auto Build" \
	openssl="BoringSSL (${BORINGSSL_COMMIT_ID})"

CMD ["sh"]
