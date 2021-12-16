
require "fox16"
require "socket"
require "resolv"

class InitWindow < Fox::FXMainWindow
  include Fox
  
  def initialize app
    super app, "Banduras Lan Messenger - Init", width: 500, height: 370
    
    @main_frame = FXVerticalFrame.new self, :opts => LAYOUT_FILL
    @checkbox_frame = FXVerticalFrame.new @main_frame, :opts => LAYOUT_FILL
    @pos_info_frame = FXVerticalFrame.new @main_frame, :opts => LAYOUT_FILL
    @complete_frame = FXHorizontalFrame.new @main_frame, :opts => LAYOUT_FILL
    
    @position_box = FXGroupBox.new @checkbox_frame, "Position", opts: FRAME_GROOVE|LAYOUT_FILL
    pos_explaination = <<EXPLAINATION
In order to be able to establish a connection between the two peers,
both must take a position. It is just important that both peers have
different positions. Choose one:
EXPLAINATION
    pos_explaination.chomp!
    @pos_explain_label = FXLabel.new @position_box, pos_explaination, opts: JUSTIFY_LEFT, padBottom: 0
    @position_choice = FXDataTarget.new 0
    @server_button = FXRadioButton.new @position_box, "Server", selector: FXDataTarget::ID_OPTION, target: @position_choice
    @client_button = FXRadioButton.new @position_box, "Client", selector: FXDataTarget::ID_OPTION + 1, target: @position_choice
    @position_choice.connect(SEL_COMMAND) {
      select_position
    }
    
    @pos_info_box = FXGroupBox.new @pos_info_frame, "Informations", opts: FRAME_GROOVE|LAYOUT_FILL
    
    @ip_label = FXLabel.new @pos_info_box, "Server IP ...", opts: JUSTIFY_RIGHT
    @pos_info_matrix = FXMatrix.new @pos_info_box, 2, opts: MATRIX_BY_COLUMNS
    @server_ip_label = FXLabel.new @pos_info_matrix, "... in case of server:", opts: JUSTIFY_RIGHT
    @server_ip_select_box = FXListBox.new @pos_info_matrix, opts: LAYOUT_FILL_X
    @ip_addresses = Socket.ip_address_list
    @ip_addresses.delete_if(&:ipv4_loopback?)
    @ip_addresses.delete_if(&:ipv6?)
    @ip_addresses.each { |ip_addr|
      @server_ip_select_box.appendItem ip_addr.ip_address
    }
    
    @client_ip_label = FXLabel.new @pos_info_matrix, "... in case of client:", opts: JUSTIFY_RIGHT
    @client_ip_field = FXTextField.new(@pos_info_matrix, 20)
    
    @complete_box = FXGroupBox.new @complete_frame, "Complete the initialization", opts: FRAME_GROOVE|LAYOUT_FILL
    @progress_bar = FXProgressBar.new @complete_box, opts: PROGRESSBAR_HORIZONTAL|LAYOUT_FILL_X
    @progress_bar.barSize = 18
    @progress_bar.total = 100
    @progress_bar.progress = 0
    
    @start_button = FXButton.new @complete_box, "Start"
    
    select_position
    
  end
  
  def select_position
    if @position_choice.value == 0  # server
      @server_ip_label.enable
      @server_ip_select_box.enable
      
      @client_ip_label.disable
      @client_ip_field.disable
    else  # client
      @server_ip_label.disable
      @server_ip_select_box.disable
      
      @client_ip_label.enable
      @client_ip_field.enable
    end
  end
  
  def init_server host
    require_relative "Server.rb"

    control_port = 20205
    key_len = 4096
    sign_algorithm = OpenSSL::Digest::SHA512

    blm = Server.new host, control_port, key_len, sign_algorithm
    puts "Server: Wait for Connection"
    blm.waitForConnection
    puts "Server: Do Handshake"
    puts "Server: Was Handshake Successful: #{blm.doHandshake}"
    puts "Server: Did Handshake"
    puts "Hash: #{blm.digest}"
    blm.socket_loop
    
    return blm
  end
  
  def init_client host
    require_relative "Client.rb"

    port = 20205
    blm = nil
    begin
      blm = Client.new host, port
    rescue Errno::ECONNREFUSED
      puts "Status: Peer refused connection"
      FXMessageBox.warning self, MBOX_OK, "The other peer has rejected a connection with us.", "The other peer has rejected a connection with us. This may be because the other peer has not yet been started. The program is ended."
      exit!
    end
    puts "Client: Do Handshake"
    puts "Client: Was Handshake Successful: #{blm.doHandshake}"
    puts "Client: Did Handshake"
    puts "Hash: #{blm.digest}"
    blm.socket_loop
    
    return blm
  end
  
  def init_messenger
    prog_th = Thread.new {
      i = 0
      loop do
        @progress_bar.progress = i
        i = 0 if i == 100
        i += 1
        sleep 0.03
      end
    }

    pos = @position_choice.value == 0 ? :server : :client
    blm = nil

    case pos
    when :server
      host = @ip_addresses[@server_ip_select_box.currentItem].ip_address
      blm = init_server host
      
      ans = FXMessageBox.question self, MBOX_YES_NO, "Verify the other peer's identity", "Is the following checksum also displayed on the other peer? #{blm.digest}"
      if ans == MBOX_CLICKED_NO
        FXMessageBox.error self, MBOX_OK, "The identity of the other peers could not be verified.", "The identity of the other peer could not be verified. The program is closed for security reasons."
        exit!
      end
    when :client
      host = @client_ip_field.text
      if ! (host =~ Resolv::IPv4::Regex)
        FXMessageBox.warning self, MBOX_OK, "IP address is invalid", "The entered IP address is not valid."
        return
      end
      blm = init_client host
      
      ans = FXMessageBox.question self, MBOX_YES_NO, "Verify the other peer's identity", "Is the following checksum also displayed on the other peer? #{blm.digest}"
      
      if ans == MBOX_CLICKED_NO
        FXMessageBox.error self, MBOX_OK, "The identity of the other peers could not be verified.", "The identity of the other peer could not be verified. The program is closed for security reasons."
        exit!
      end
    end
    
    @main_window.connect_blm blm
    @main_window.show(Fox::PLACEMENT_SCREEN)
    
    prog_th.kill
    self.close
  end
  
  def connect_main_window main
    @main_window = main
    @start_button.connect(SEL_COMMAND) {
      init_messenger
    }
  end
  
  def create
    super
    show(Fox::PLACEMENT_SCREEN)
  end
end
