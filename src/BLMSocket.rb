
require "base64"

require_relative "JobQueue.rb"

# BLM = Banduras Lan Messenger
class BLMSocket
  
  attr_accessor :download_dir
  
  def initialize pos
    @pos = pos
    @queue = JobQueue.new
    @actions = Hash.new
    @download_dir = "./"
  end
  
  def send_message msg
    @queue.send_message msg
  end
  
  def send_file filename, file_path
    @queue.send_file filename, file_path
  end
  
  def add_action event, &block
    @actions[event] = block
  end
  
  def socket_loop
    puts "in socket_loop"
    Thread.new {
      loop do
        sleep 0.1
        #pp @queue
        
        exist_command = false
        begin
          exist_command = @socket.read_nonblock(1)
        rescue IO::WaitReadable || IO::WaitWriteable
          #puts "Status: No command to read; I can send my command"
          # too much output for the console :-)
        rescue Errno::ECONNRESET || EOFError
          puts "Status: The opposite side has broken off the connection."
          @actions[:conn_reset].call if @actions[:conn_reset]
          exit!
        end
        
        if exist_command
          command = @socket.gets.chomp.to_sym
          case command
          when :Message
            msg = @socket.gets.chomp
            puts "Message: #{msg}"
            if @actions[:receive_message]
              @actions[:receive_message].call msg
            end
          when :File
            case @pos
            when :client
              puts "Status: Receive command to receive file"
              port = @socket.gets.chomp.to_i
              puts "Status: Receive port"
              answer = @socket.gets.chomp.to_sym
              if answer == :ready
                puts "Status: Receive command to send file"
                client_receive_file port
              else
                puts "Error: Server does not respond with ready-code: #{answer.to_s}"
              end
            when :server
              puts "Status: Receive command to receive file"
              port = 0
              loop do
                port = rand(20205...20400)
                break if ! @used_ports.include? port
              end
              @used_ports << port
              @socket.puts port
              server_receive_file port
            end
          end
        elsif @queue.exist_task?
          task = @queue.pop_task
          puts "Status: I have a task - type: #{task[0].to_s}"
          case task[0]
          when :SendMessage
            @socket.puts "CMessage"
            @socket.puts task[1]
          when :SendFile
            @socket.puts "CFile" 
            
            case @pos
            when :client
              puts "Status: Sending file"
              port = @socket.gets.chomp.to_i
              puts "Status: Receive port"
              answer = @socket.gets.chomp.to_sym
              if answer == :ready
                puts "Status: Receive command to send file"
                client_send_file task, port
              else
                puts "Error: Server does not respond with ready-code: #{answer.to_s}"
              end
            when :server
              puts "Status: Sending file"
              port = 0
              loop do
                port = rand(20206...20400)
                break if ! @used_ports.include? port
              end
              @used_ports << port
              @socket.puts port
              server_send_file task, port
            end
            
          end
        end
      end
    }
  end
  
  protected
  
  def receive_file_via_socket socket
      puts "Status: Receive metadata"
      file_digest = socket.gets.chomp
      filename = socket.gets.chomp
      
      if @actions[:receive_file]
        @actions[:receive_file].call filename
      end
      puts "Status: Receive content"
      prepared_content = socket.gets.chomp
      socket.puts "received"
      puts "Status: Prepare content"
      content = Base64.decode64 prepared_content
      puts "Status: Calculate checksum"
      calced_file_digest = Digest::MD5.hexdigest content

      if file_digest != calced_file_digest
        puts "Error: File was received with error. Save file anyway."
        if @actions[:bad_file_received]
          @actions[:bad_file_received].call filename
        end
      else
        puts "Status: File successful received!"
      end

      puts "Status: Write content to file #{filename}"
      File.write "#{@download_dir}/#{filename}", content
      puts "Status: Received file"
  end
  
  def send_file_via_socket task, socket
      puts "Status: Reading file"
      content = File.read task[2]
      puts "Status: Calculate checksum"
      file_digest = Digest::MD5.hexdigest content
    
      puts "Status: Sending metadata"
      socket.puts file_digest
      socket.puts task[1]
      if @actions[:send_file]
        @actions[:send_file].call task[1]
      end
      puts "Status: Prepare file to send"
      prepared_content = Base64.encode64(content)
      prepared_content.gsub!(/\n/, "")
      puts "Status: Sending file"
      #sleep 0.1
      socket.puts prepared_content
      puts "Status: File sended"
      ans = socket.gets.chomp.to_sym
      if ans == :received
        puts "Status: File sent successfully."
      else
        puts "Status: File send failed."
      end
  end
  
  def prepare_client port
    puts "Status: Open connection to peer"
    ft_client = TCPSocket.new @host, port
    # ft socket = file transfer socket
    ft_socket = OpenSSL::SSL::SSLSocket.new ft_client
    ft_socket.sync_close = true
    ft_socket.connect
    
    puts "Status: Check identity"
    if Digest::SHA256.hexdigest(ft_socket.peer_cert.to_s) != @digest
      puts "Error: Server has changed it certificate. This can indicate that an attacker want to receive the file"
      return
    end
    
    @socket.puts "connected"
    
    return ft_socket
  end
  
  def client_receive_file port
    socket = prepare_client port
    
    Thread.new {
      receive_file_via_socket socket
      
      socket.close
    }
  end
  
  def client_send_file task, port
    socket = prepare_client port
    
    Thread.new {
      send_file_via_socket task, socket
      
      socket.close
    }
  end
  
  def server_send_file task, port
    socket = prepare_server port
    
    Thread.new {
      send_file_via_socket task, socket
      
      socket.close
      @used_ports.delete port
    }
  end
  
  def prepare_server port
    puts "Status: Prepare socket and server things"
    server = TCPServer.new port
    
    ssl_context = OpenSSL::SSL::SSLContext.new
    ssl_context.add_certificate @cert, @key
    ft_server = OpenSSL::SSL::SSLServer.new server, ssl_context
    ft_server.start_immediately = true
    
    #sleep 1 replace it with start_immediately
    puts "Status: Say peer that I am ready"
    @socket.puts "ready"
    
    puts "Status: Conncet to peer"
    socket = ft_server.accept
    right_client = @socket.gets.chomp.to_sym
    #puts "Status: Received #{right_client.to}"
    if right_client == :connected
      puts "Status: No hacker"
    else
      puts "Error: Someone is trying to send a file to you - abort file transfer"
      return
    end
    
    return socket
  end
  
  def server_receive_file port
    socket = prepare_server port
    
    Thread.new {
      receive_file_via_socket socket
      
      socket.close
      @used_ports.delete port
    }
  end
  
end