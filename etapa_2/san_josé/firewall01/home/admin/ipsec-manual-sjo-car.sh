#!/bin/bash
ip xfrm state add src 172.24.133.76 dst 172.24.133.84 proto esp spi 0x1001 mode tunnel \
  enc aes 0x147a0cbc9062b113ff5053bdb6f706b71b1bc3a877377314950af3ff67f3c9f8 \
  auth sha256 0xec05f728a8c77c598e09d7981756b1ce8b1164ba05bdf36ae578425c83bcbf41

ip xfrm state add src 172.24.133.84 dst 172.24.133.76 proto esp spi 0x1002 mode tunnel \
  enc aes 0xc9b7ff6fe4c393e38c2cd132c5cf7d3e068c8204e5f18926378177a26431ba77 \
  auth sha256 0xb9a287a0726b93abe38bf9d0fd610f7711ea3e83fc59648184eb0ab573e744ff

ip xfrm policy add src 10.4.0.0/20 dst 10.4.32.0/20 dir out \
  tmpl src 172.24.133.76 dst 172.24.133.84 proto esp mode tunnel

ip xfrm policy add src 10.4.32.0/20 dst 10.4.0.0/20 dir in \
  tmpl src 172.24.133.84 dst 172.24.133.76 proto esp mode tunnel
