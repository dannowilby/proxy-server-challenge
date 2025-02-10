# === First stage: Build the Go binary ===
FROM golang AS builder

WORKDIR /app
COPY metrics /app

RUN go mod tidy
RUN go build -o metrics_server main.go

# === Second stage: NGINX with Go server ===
FROM nginx:latest

COPY proxy/nginx.conf /etc/nginx/nginx.conf
COPY proxy/.htpasswd /etc/nginx/.htpasswd
RUN chmod 644 /etc/nginx/.htpasswd

COPY --from=builder /app/metrics_server /usr/local/bin/metrics_server
RUN chmod +x /usr/local/bin/metrics_server

EXPOSE 8080 9090

CMD ["/bin/sh", "-c", "/usr/local/bin/metrics_server & nginx -g 'daemon off;'"]