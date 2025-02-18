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

ENV NGINX_VERSION=1.27.1
ENV MODULE_VERSION=master

WORKDIR /usr/local/src
RUN curl -fsSL http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar xz

RUN git clone --depth 1 -b ${MODULE_VERSION} https://github.com/chobits/ngx_http_proxy_connect_module.git

WORKDIR /usr/local/src/nginx-${NGINX_VERSION}
RUN patch -p1 < ../ngx_http_proxy_connect_module/patch/proxy_connect_rewrite_102101.patch

RUN ./configure \
    --prefix=/etc/nginx \
    --with-compat \
    --with-http_ssl_module \
    --add-module=../ngx_http_proxy_connect_module && \
    make -j$(nproc) && make install

# === Third stage: Run Nginx and Go server ===
FROM debian:bookworm AS runtime

RUN apt-get update && apt-get install -y \
    libpcre3 \
    zlib1g \
    libssl3 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /etc/nginx /etc/nginx

# Copy over auth
COPY proxy/.htpasswd /etc/nginx/.htpasswd
COPY proxy/cert.pem /etc/nginx/cert.pem
COPY proxy/key.pem /etc/nginx/key.pem

COPY proxy/nginx.conf /etc/nginx/conf/nginx.conf

COPY --from=gobuilder /app/metrics_server /usr/local/bin/metrics_server
RUN chmod +x /usr/local/bin/metrics_server

EXPOSE 8080

CMD ["/bin/sh", "-c", "/usr/local/bin/metrics_server & /etc/nginx/sbin/nginx -g 'daemon off;'"]