#!/usr/bin/ruby
require "socket"

def pin(message)
  case message
  when "on"
    p message
  when "off"
    p "err"
  end
end

if __FILE__ == $0
  udps = UDPSocket.open()
  udps.bind("0.0.0.0", 10000)

  loop do
    data = udps.recv(65535).chomp
    pin(data)
  end

  udps.close
end
