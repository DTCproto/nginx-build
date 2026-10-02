# 前置镜像：Debian slim + Clang/LLVM 工具链
# 推送为 debian-slim:clang / debian-slim:clang-<LLVM_VERSION>
FROM debian:trixie-slim

ARG LLVM_VERSION="23"

# llvm.sh 所需最小依赖: lsb_release / wget / gpg + ca-certificates
RUN set -eux; \
	apt-get update; \
	DEBIAN_FRONTEND=noninteractive \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		wget \
		gnupg \
		lsb-release \
		; \
	apt-get clean; \
	rm -rf /tmp/* /var/lib/apt/lists/*;

#################################################################################################

### 安装 Clang / LLVM 工具链
RUN set -eux; \
	mkdir -p /opt/clang; \
	cd /opt/clang; \
	wget -qO llvm.sh \
		--tries=5 \
		--timeout=30 \
		--waitretry=5 \
		https://apt.llvm.org/llvm.sh; \
	chmod +x llvm.sh; \
	./llvm.sh ${LLVM_VERSION} all; \
	# 创建符号链接，以便 CMake 能找到 clang/clang++
	ln -sf /usr/bin/clang-${LLVM_VERSION} /usr/local/bin/clang; \
	ln -sf /usr/bin/clang++-${LLVM_VERSION} /usr/local/bin/clang++; \
	ln -sf /usr/bin/lld-${LLVM_VERSION} /usr/local/bin/lld; \
	cd /; \
	rm -rf /opt/clang /tmp/* /var/lib/apt/lists/*;

# 将 Clang 的 bin 目录置于 PATH 最前面
ENV PATH="/usr/lib/llvm-${LLVM_VERSION}/bin:${PATH}"

ENV CC=clang
ENV CXX=clang++
ENV AR=llvm-ar
ENV RANLIB=llvm-ranlib
ENV NM=llvm-nm

LABEL \
	description="Debian slim with Clang/LLVM toolchain" \
	maintainer="Custom Auto Build" \
	clang="LLVM/Clang (${LLVM_VERSION})"
