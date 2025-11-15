FROM alpine:latest

# Install keepalived and other required packages
RUN apk add --no-cache \
    keepalived \
    iputils \
    iproute2 \
    bash

# Create keepalived config directory
RUN mkdir -p /etc/keepalived

# Expose VRRP protocol
EXPOSE 112/udp

# Run keepalived in foreground
CMD ["keepalived", "--dont-fork", "--log-console", "--log-detail"]
