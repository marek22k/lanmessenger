
class JobQueue
  
  def initialize
    @queue = []
  end
  
  def exist_task?
    return ! @queue.empty?
  end
  
  def pop_task
    return @queue.pop
  end
  
  def pending_tasks
    return @queue.length
  end
  
  def send_file filename, file_path
    @queue << [:SendFile, filename, file_path]
  end
  
  def send_message msg
    @queue << [:SendMessage, msg]
  end
  
end