
require "fox16"

class MainWindow < Fox::FXMainWindow
  include Fox
  
  def initialize app
    super app, "Banduras Lan Messenger", width: 350, height: 600
    
    # Erstelle frames
    @main_frame = FXVerticalFrame.new self, opts: LAYOUT_FILL
    @message_frame = FXHorizontalFrame.new @main_frame, opts: LAYOUT_FILL
    @send_frame = FXHorizontalFrame.new @main_frame, opts: LAYOUT_FILL_X
    @file_frame = FXHorizontalFrame.new @main_frame, opts: LAYOUT_FILL_X
    
    # Erstelle Inhalte des messageFrames
    @msg_box = FXText.new @message_frame, opts: LAYOUT_FILL|TEXT_AUTOSCROLL
    @msg_box.editable = false
    
    # Erstelle Inhalte des sendFrames
    @send_text_field = FXTextField.new @send_frame, 36, opts: LAYOUT_FILL_X
    @send_text_button = FXButton.new @send_frame, "-->"
    @send_text_button.connect(SEL_COMMAND) {
      click_on_send_button
    }
    
    @file_button = FXButton.new @file_frame, "Send file"
    @file_button.connect(SEL_COMMAND) {
      click_on_file_button
    }
    
    @download_dir_button = FXButton.new @file_frame, "Select download directory"
    @download_dir_button.connect(SEL_COMMAND) {
      change_download_directory
    }
  end
  
  def change_download_directory
    dialog = Fox::FXDirDialog.getOpenDirectory self, "Select download directory", @blm.download_dir
    if dialog
      if Dir.exist? dialog
        @blm.download_dir = dialog
        FXMessageBox.information self, MBOX_OK, "Download directory changed successfully.", "The download directory was successfully changed to #{dialog}."
      else
        FXMessageBox.error self, MBOX_OK, "Directory does not exist", "The selected directory does not exist. The download directory is not changed."
      end
    else
      FXMessageBox.error self, MBOX_OK, "Dialog canceled", "No directory was selected. The download directory is not changed."
    end
  end
  
  def connect_blm blm
    @blm = blm
    
    @blm.add_action(:receive_message) { |msg|
      receive_message "Person", msg
    }
    
    @blm.add_action(:receive_file) { |filename|
      receive_message "Event", "Receive file #{filename}"
    }
    
    @blm.add_action(:send_file) { |filename|
      receive_message "Event", "Send file #{filename}"
    }
    
    @blm.add_action(:bad_file_received) { |filename|
      receive_message "Event", "File #{filename} was transferred incorrectly. It will be saved anyway."
    }
    
    @blm.add_action(:conn_reset) {
      FXMessageBox.error self, MBOX_OK, "The opposite side has broken off the connection.", "The opposite side has broken off the connection. The reason for this is unknown. The program is ended."
    }
  end
  
  def receive_message person, text
    @msg_box.text = "#{person}: #{text}\n#{@msg_box.text}"
  end
  
  def click_on_send_button
    puts "You clicked on Send Button"
    msg = @send_text_field.text
    @send_text_field.text = ""
    @blm.send_message msg
    receive_message "I", msg
  end
  
  def click_on_file_button
    puts "You clicked on File Button"
    files = FXFileDialog.getOpenFilenames(self, "window name goes here", ENV["HOME"] + "/")
    if files.empty?
      FXMessageBox.warning self, MBOX_OK, "No file was selected", "No file was selected. The process is canceled."
      return
    end
    
    files.each { |file|
      if ! File.readable? file
        FXMessageBox.warning self, MBOX_OK, "I cannot read the file", "I cannot read the file #{file}. This file is therefore not sent."
        return
      end
      filename = File.basename file
      @blm.send_file filename, file
    }
  end
  
  def create
    super
  end
end
