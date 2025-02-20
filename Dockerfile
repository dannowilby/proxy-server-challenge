# === First stage: Build the Go binary ===
FROM golang AS gobuilder

WORKDIR /app
COPY metrics /app

RUN go mod tidy
RUN go build -o metrics_server main.go

# === Second stage: Build NGINX with patch ===
FROM debian:bookworm AS builder

RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    build-essential \
    libpcre3-dev \
    zlib1g-dev \
    libssl-dev \
    git

ENV NGINX_VERSION=1.25.3.1
ENV MODULE_VERSION=master

WORKDIR /build
RUN curl -fsSL https://openresty.org/download/openresty-${NGINX_VERSION}.tar.gz | tar xz

RUN git clone --depth 1 -b ${MODULE_VERSION} https://github.com/chobits/ngx_http_proxy_connect_module.git

WORKDIR /build/openresty-${NGINX_VERSION}

RUN ./configure \
    --with-http_ssl_module \
    --add-module=../ngx_http_proxy_connect_module
RUN patch -d build/nginx-1.25.3 -p1 < ../ngx_http_proxy_connect_module/patch/proxy_connect_rewrite_102101.patch
RUN make && make install
RUN cd /usr/local/openresty/nginx && ls


# === Third stage: Run Nginx and Go server ===
FROM debian:bookworm AS runtime

RUN apt-get update && apt-get install -y \
    libpcre3 \
    zlib1g \
    libssl3 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/openresty /usr/local/openresty

# Copy over auth
COPY proxy/.htpasswd /usr/local/openresty/nginx/conf/.htpasswd
COPY proxy/cert.pem /usr/local/openresty/nginx/conf/cert.pem
COPY proxy/key.pem /usr/local/openresty/nginx/conf/key.pem

COPY proxy/proxy_auth.lua /usr/local/openresty/nginx/conf/proxy_auth.lua

COPY proxy/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

COPY --from=gobuilder /app/metrics_server /usr/local/bin/metrics_server
RUN chmod +x /usr/local/bin/metrics_server

EXPOSE 8080

CMD ["/bin/sh", "-c", "/usr/local/bin/metrics_server & /usr/local/openresty/nginx/sbin/nginx -g 'daemon off;'"]