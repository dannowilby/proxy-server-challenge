# === First Stage: Build the Go Metrics Server ===
FROM golang AS builder

WORKDIR /app
COPY metrics /app

RUN go mod tidy
RUN go build -o metrics_server main.go

# === Second Stage: Squid Proxy + Metrics Server ===
FROM ubuntu:latest

RUN apt update && apt install -y squid apache2-utils

# Copy Squid configuration and password file
COPY proxy/squid.conf /etc/squid/squid.conf
# COPY squid/passwords /etc/squid/passwords
# RUN chmod 640 /etc/squid/passwords

# Copy the compiled Go metrics server
COPY --from=builder /app/metrics_server /usr/local/bin/metrics_server

# Expose Squid proxy and metrics server ports
EXPOSE 3128 9090

# Start Squid and Metrics Server
CMD service squid start && /usr/local/bin/metrics_server