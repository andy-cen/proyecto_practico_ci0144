#!/bin/bash
ip xfrm state flush
ip xfrm policy flush

# SPI 0x1001: sjo -> car
ip xfrm state add src 172.24.133.76 dst 172.24.133.84 proto esp spi 0x1001 mode tunnel \
  enc aes secret \
  auth sha256 secret

# SPI 0x1002: car -> sjo
ip xfrm state add src 172.24.133.84 dst 172.24.133.76 proto esp spi 0x1002 mode tunnel \
  enc aes secret \
  auth sha256 secret

# SPD
ip xfrm policy add src 10.4.32.0/20 dst 10.4.0.0/20 dir out \
  tmpl src 172.24.133.84 dst 172.24.133.76 proto esp mode tunnel

ip xfrm policy add src 10.4.0.0/20 dst 10.4.32.0/20 dir in \
  tmpl src 172.24.133.76 dst 172.24.133.84 proto esp mode tunnel

ip xfrm policy add src 10.4.0.0/20 dst 10.4.32.0/20 dir fwd \
  tmpl src 172.24.133.76 dst 172.24.133.84 proto esp mode tunnel
