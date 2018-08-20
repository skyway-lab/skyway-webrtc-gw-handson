#!/usr/bin/ruby
require "socket"
require "pi_piper"

def pin(pin, message)
  case message
  when "on"
    pin.on
  when "off"
    pin.off
  end
end

if __FILE__ == $0
  gpio_21 = PiPiper::Pin.new(:pin => 21, :direction => :out)

  udps = UDPSocket.open()
  udps.bind("0.0.0.0", 10000)

  loop do
    data = udps.recv(65535).chomp
    pin(gpio_21, data)
  end

  udps.close
end
