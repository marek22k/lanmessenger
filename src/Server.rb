
require "socket"
require "openssl"
require "digest"
require "securerandom"

require_relative "BLMSocket.rb"

class Server < BLMSocket
  
  attr_reader :digest
  
  def initialize host, controlPort, keyLen, signAlgorithm
    super(:server)
    
    @key = OpenSSL::PKey::RSA.new keyLen
    
    @cert = createCertificate @key, signAlgorithm

    server = TCPServer.new host, controlPort
    ssl_context = OpenSSL::SSL::SSLContext.new
    ssl_context.add_certificate @cert, @key
    @ssl_server = OpenSSL::SSL::SSLServer.new server, ssl_context
    
    @used_ports = []

    #@digest = Digest::SHA256.hexdigest ssl_context.cert.to_s
    @digest = Digest::SHA256.hexdigest @cert.to_s
  end
  
  def waitForConnection
    @socket = @ssl_server.accept
    
    return true
  end
  
  def doHandshake
    receiveHandshake = @socket.gets.chomp
    if receiveHandshake != "HelloServer"
      return false
    end
    @socket.puts "HelloClient"
    return true
  end
  
  protected

  def createCertificate key, signAlgorithm
    cert = OpenSSL::X509::Certificate.new
    cert.version = 1
    cert.serial = SecureRandom.hex(2).to_i 16
    cert.subject = OpenSSL::X509::Name.new [["CN", "Banduras Lan Messenger"]]
    cert.issuer = cert.subject
    cert.public_key = key.public_key
    cert.not_before = Time.now
    cert.not_after = cert.not_before + 2 * 24 * 60 * 60 # 2 days validity
    cert.sign(key, signAlgorithm.new)
    
    return cert
  end
  
end
