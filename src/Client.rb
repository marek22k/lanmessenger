
require "socket"
require "openssl"
require "digest"

require_relative "BLMSocket.rb"

class Client < BLMSocket
  
  attr_reader :digest
  
  def initialize host, controlPort
    super(:client)
    
    @host = host
    
    client = TCPSocket.new @host, controlPort
    
    @socket = OpenSSL::SSL::SSLSocket.new client
    @socket.sync_close = true # Schliest den Klient automatisch, wenn die SSL Verbindung geschlossen wird
    @socket.connect
    
    @digest = Digest::SHA256.hexdigest @socket.peer_cert.to_s
  end
  
  def doHandshake
    @socket.puts "HelloServer"
    receiveHandshake = @socket.gets.chomp
    if receiveHandshake != "HelloClient"
      return false
    end
    return true
  end
  
end

