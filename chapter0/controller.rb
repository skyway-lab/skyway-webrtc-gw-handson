#!/usr/bin/ruby
require "socket"

if ARGV.length != 1
  exit(0)
end

message = ARGV[0]
udp = UDPSocket.open()
sockaddr = Socket.pack_sockaddr_in(10000, "127.0.0.1")
udp.send(message, 0, sockaddr)
udp.close
