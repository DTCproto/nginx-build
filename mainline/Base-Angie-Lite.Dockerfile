ARG BASE_IMAGE="gcc:15-trixie"

FROM ${BASE_IMAGE} AS builder

ARG NGINX_COMMIT_ID="HEAD~0"
ARG BORINGSSL_COMMIT_ID="HEAD~0"

ARG NGINX_PATCH_LIBS="native"

ARG NGX_BROTLI_COMMIT_ID="HEAD~0"
ARG BROTLI_LIB_COMMIT_ID="v1.2.0"

ARG NGX_ZSTD_COMMIT_ID="HEAD~0"
ARG NGX_ZSTD_LEE_COMMIT_ID="HEAD~0"

ARG NGX_GEOIP2_COMMIT_ID="HEAD~0"
ARG NGX_HEADERS_MORE_COMMIT_ID="HEAD~0"

# nginx:alpine nginx -V

ARG NGINX_CC_OPT="-O2 -fstack-protector-strong -fstack-clash-protection -fno-plt -Wformat -Werror=format-security -pipe -fno-semantic-interposition -fno-strict-aliasing -fomit-frame-pointer"
ARG NGINX_LD_OPT="-Wl,-O2 -Wl,--as-needed -Wl,--sort-common -Wl,-z,now -Wl,-z,relro -Wl,-z,pack-relative-relocs -Wl,--hash-style=gnu -Wl,--strip-all"

# 临时忽略补丁带来的警告异常
ARG NGINX_CC_OPT_EXT_NO_ERROR=""
ARG NGINX_LD_OPT_EXT_NO_ERROR=""

ARG NGINX_MODULES_PATH="/usr/lib/nginx/modules"

ARG PKG_CONFIG_HOME="/usr/src/pkgs"
ARG PKG_CONFIG_LIB_DIR="lib"
ARG PKG_CONFIG_PATH="${PKG_CONFIG_HOME}/${PKG_CONFIG_LIB_DIR}/pkgconfig"

# https://github.com/nginx/ci-self-hosted/blob/main/.github/workflows/nginx-buildbot.yml

ARG NGINX_BASE_CONFIG="\
		--prefix=/etc/nginx \
		--sbin-path=/usr/sbin/nginx \
		--modules-path=${NGINX_MODULES_PATH} \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/var/log/nginx/error.log \
		--http-log-path=/var/log/nginx/access.log \
		--pid-path=/var/run/nginx.pid \
		--lock-path=/var/run/nginx.lock \
		--http-client-body-temp-path=/var/cache/nginx/client_temp \
		--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
		--user=nginx \
		--group=nginx \
	"

ARG NGINX_CORE_MODULES="\
#		--with-http_acme_module \
		--with-http_auth_request_module \
		--with-http_sub_module \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-http_secure_link_module \
		--with-http_stub_status_module \
		--with-http_slice_module \
		--with-http_v2_module \
		--with-http_v3_module \
		--with-http_ssl_module \
		--with-http_realip_module \
		--with-stream \
#		--with-stream_acme_module \
		--with-stream_ssl_module \
		--with-stream_ssl_preread_module \
		--with-stream_realip_module \
		--with-threads \
		--with-compat \
		--with-file-aio \
	"

ARG NGINX_WITHOUT_MODULES="\
		--without-http_ssi_module \
		--without-http_scgi_module \
		--without-http_uwsgi_module \
		--without-http_fastcgi_module \
		--without-http_memcached_module \
	"

ARG NGINX_DYNAMIC_MODULES="\
	"

ARG NGINX_DYNAMIC_MODULES_EXTERNAL="\
		--add-dynamic-module=/usr/src/ngx_brotli \
		--add-dynamic-module=/usr/src/zstd-nginx-module \
		--add-dynamic-module=/usr/src/ngx_http_geoip2_module \
		--add-dynamic-module=/usr/src/headers-more-nginx-module \
	"

# gnupg 仅在验证 GPG 签名时需要

RUN set -eux; \
	###【alpine】
	# addgroup -S nginx; \
	# adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx; \
	###【Debian/Ubuntu】
	groupadd -r nginx; \
	useradd -r -g nginx -s /sbin/nologin -d /var/cache/nginx nginx; \
	mkdir -p /var/cache/nginx; \
	chown -R nginx:nginx /var/cache/nginx; \
	apt-get update; \
	DEBIAN_FRONTEND=noninteractive \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		tzdata \
		tree \
		git \
		make \
		cmake \
		ninja-build \
		meson \
		libtool \
		bash \
		zstd \
		7zip \
		unzip \
		pkg-config \
		build-essential \
		libgd-dev \
		libgd-tools \
		libmaxminddb-dev \
		libxslt-dev \
		libxml2-dev \
		libpcre2-dev \
		zlib1g-dev \
		libperl-dev \
		; \
	rm -rf /var/lib/apt/lists/*; \
	mkdir -p /usr/src;

#################################################################################################

RUN set -eux; \
	git clone --recurse-submodules https://github.com/webserver-llc/angie /usr/src/nginx; \
	cd /usr/src/nginx; \
	git checkout --force --quiet ${NGINX_COMMIT_ID}; \
	git submodule update --init --recursive;

# 补丁
COPY patch/${NGINX_PATCH_LIBS}/* /opt/build/patch/

RUN set -eux; \
	cd /usr/src/nginx; \
	find /opt/build/patch/ -name "*.patch" | sort | xargs -I {} bash -c 'patch -p1 -N < "{}"';

#################################################################################################
### ngx_http_brotli_static_module.so;
### ngx_http_brotli_filter_module.so;

RUN set -eux; \
	git clone --recurse-submodules https://github.com/google/ngx_brotli /usr/src/ngx_brotli; \
	cd /usr/src/ngx_brotli; \
	git checkout --force --quiet ${NGX_BROTLI_COMMIT_ID}; \
	git submodule update --init --recursive;

# 更新依赖版本
RUN set -eux; \
	cd /usr/src/ngx_brotli/deps/brotli; \
	git fetch --all; \
	git checkout --force --quiet ${BROTLI_LIB_COMMIT_ID};

#################################################################################################
### ngx_http_zstd_static_module.so;
### ngx_http_zstd_filter_module.so;

RUN set -eux; \
	git clone --recurse-submodules https://github.com/tokers/zstd-nginx-module /usr/src/zstd-nginx-module; \
	cd /usr/src/zstd-nginx-module; \
	git checkout --force --quiet ${NGX_ZSTD_COMMIT_ID}; \
	git submodule update --init --recursive;

#RUN set -eux; \
#	git clone --recurse-submodules https://github.com/HanadaLee/ngx_http_zstd_module /usr/src/zstd-nginx-module; \
#	cd /usr/src/zstd-nginx-module; \
#	git checkout --force --quiet ${NGX_ZSTD_LEE_COMMIT_ID}; \
#	git submodule update --init --recursive;

#################################################################################################
### ngx_http_geoip2_module.so
### ngx_stream_geoip2_module.so

RUN set -eux; \
	git clone --recurse-submodules https://github.com/leev/ngx_http_geoip2_module /usr/src/ngx_http_geoip2_module; \
	cd /usr/src/ngx_http_geoip2_module; \
	git checkout --force --quiet ${NGX_GEOIP2_COMMIT_ID}; \
	git submodule update --init --recursive;

#################################################################################################
### ngx_http_headers_more_filter_module.so

RUN set -eux; \
	git clone --recurse-submodules https://github.com/openresty/headers-more-nginx-module /usr/src/headers-more-nginx-module; \
	cd /usr/src/headers-more-nginx-module; \
	git checkout --force --quiet ${NGX_HEADERS_MORE_COMMIT_ID}; \
	git submodule update --init --recursive;

#################################################################################################

#RUN set -eux; \
#	tree ${PKG_CONFIG_HOME};

#################################################################################################

# Nginx不作为被依赖的共享库，无需-fPIC
# Nginx Core + Dynamic Modules
# 分开编译会导致部分模块加载异常(例如ngx_http_perl_module)
RUN set -eux; \
	cd /usr/src/nginx; \
	./configure ${NGINX_BASE_CONFIG} ${NGINX_CORE_MODULES} ${NGINX_WITHOUT_MODULES} ${NGINX_DYNAMIC_MODULES} ${NGINX_DYNAMIC_MODULES_EXTERNAL} \
	--build="Nginx(Angie) With Dynamic Modules[SSL Static]" \
	--with-cc=c++ \
	--with-cc-opt="${NGINX_CC_OPT} ${NGINX_CC_OPT_EXT_NO_ERROR} -I/usr/boringssl/include -x c" \
	--with-ld-opt="${NGINX_LD_OPT} ${NGINX_LD_OPT_EXT_NO_ERROR} -L/usr/boringssl/lib"; \
	make -j"$(nproc)"; \
	make install;

RUN set -eux; \
	cd /usr/src/nginx; \
	mkdir /etc/nginx/http.d/; \
	mkdir /etc/nginx/stream.d/; \
	mkdir -p /usr/share/nginx/html/; \
	install -m644 docs/html/index.html /usr/share/nginx/html/; \
	install -m644 docs/html/50x.html /usr/share/nginx/html/;

# 精简运行文件
RUN set -eux; \
	strip /usr/sbin/nginx; \
	strip ${NGINX_MODULES_PATH}/*;

# 配置环境变量和工作目录
WORKDIR /etc/nginx

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/start.sh /etc/nginx/start.sh

RUN set -eux; \
	ln -s ${NGINX_MODULES_PATH} /etc/nginx/modules; \
	# forward request and error logs to docker log collector
	ln -sf /dev/stdout /var/log/nginx/access.log; \
	ln -sf /dev/stderr /var/log/nginx/error.log;

RUN set -eux; \
	chown -R nginx:nginx /etc/nginx/start.sh; \
	chown -R nginx:nginx /etc/nginx/nginx.conf; \
	chmod -R 755 /etc/nginx/start.sh; \
	chmod -R 644 /etc/nginx/nginx.conf;

# clean
RUN set -eux; \
	rm -rf \
		/usr/src \
		/usr/libexec \
		; \
	rm -rf /tmp/* /var/lib/apt/lists/*;

ENV LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:/usr/boringssl/lib"

ENV TZ=Asia/Shanghai
ENV LC_TIME=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

LABEL \
	description="Nginx(Angie) Docker Build with BoringSSL" \
	maintainer="Custom Auto Build" \
	openssl="BoringSSL (${BORINGSSL_COMMIT_ID})" \
	nginx="Nginx(Angie) (${NGINX_COMMIT_ID})"

# 定义容器暴露的端口
# EXPOSE 80 443

# 挂载 NGINX 配置和站点目录
VOLUME /etc/nginx/http.d /etc/nginx/stream.d

STOPSIGNAL SIGTERM

# 设置容器启动命令
ENTRYPOINT ["/bin/bash", "/etc/nginx/start.sh"]

# 设置容器启动命令(ENTRYPOIN[]的默认参数)
CMD ["-g", "daemon off;"]
