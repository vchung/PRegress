require 'fileutils'
require 'date'

module TxtJobLoggable
  
  attr_accessor :log_file

  def write_log(s_msg_type, s_message)
    
    # creates a directory and all its parent directories
    s_dir_name = File.dirname(@log_file)
    FileUtils.mkdir_p(s_dir_name) 
    
    unless s_message.empty?
      File.open(@log_file, "a") do |o_file| 
        o_file.write("[#{s_msg_type}] #{get_current_datetime_str()} #{s_message} \n") 
      end
    end
  end
  
  def get_current_datetime_str()
    return DateTime.now.strftime("%m/%d/%Y %H:%M:%S")
  end
  
end