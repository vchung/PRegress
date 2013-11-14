require 'yaml'
require 'tree'
require 'bin/txt_job_loggable'
require 'bin/job_runner'

class ScriptRunner
  include TxtJobLoggable

  attr_accessor :reserved_keywords
  attr_accessor :cur_node_id
  
  def initialize()
    @cur_node_id = 0
    @reserved_keywords = ["Command", "Directory", "Program", "User", "Serial", "Parallel", "Label"]
  end
  
  def run_script(o_root_job)
    o_root_job.run()
  end

  def setup(s_yaml_file)
  
    begin

      raise "Yaml file name is not provided" if s_yaml_file.nil?
      
      h_config = YAML.load_file("app/#{s_yaml_file}.yml")
      @log_file = File.join(Dir.pwd, "log", "#{s_yaml_file}.log")
      o_root_settings_node = create_settings_node("Root")
      parse_script(o_root_settings_node, h_config)
      process_settings(o_root_settings_node)
      
      o_root_job = build_job_tree(o_root_settings_node)
      
      return o_root_job
      
    rescue Exception => o_exc
      write_log("ERROR", "Batch job failed")
      write_log("ERROR", o_exc.message)
      write_log("ERROR", o_exc.inspect)
      write_log("ERROR", o_exc.backtrace)
      raise o_exc
    end
  end
  
  def parse_script(o_node, h_settings)
    h_settings.each do |s_key, x_val|
      if x_val.kind_of? Hash # subtask
        o_child_node = create_settings_node(s_key, o_node)
        parse_script(o_child_node, x_val)
      else # settings
        create_settings_node(s_key, o_node, {s_key => x_val})
      end
    end
  end
  
  def create_settings_node(s_label, o_parent=nil, o_content=nil)
    @cur_node_id = @cur_node_id + 1
    s_node_name = "#{@cur_node_id}-#{s_label}"
    o_node = Tree::TreeNode.new(s_node_name)
    o_parent << o_node unless o_parent.nil?
    if o_content.nil?
      o_node.content = {"Label" => s_label}
    else
      o_node.content = o_content
    end
    return o_node
  end
  
  def process_settings(o_root_settings_node)
    # all settings nodes are leaf nodes
    
    # 1. collapse leaf nodes, store settings in parent nodes' content
    o_root_settings_node.each_leaf do |o_node|
      o_parent = o_node.parent()
      o_parent.content = o_parent.content.merge(o_node.content)
    end
    
  end
  
  def build_job_tree(o_settings_root_node)
  
    h_nodes = {}
    o_root_job = nil
    
    o_settings_root_node.each do |o_set_node|
      next if o_set_node.is_leaf?
      
      o_node = Tree::TreeNode.new(o_set_node.name)
      h_nodes[o_node.name] = o_node
      
      unless o_set_node.is_root?
        o_par_set_node = o_set_node.parent
        o_parent = h_nodes[o_par_set_node.name]
        o_parent << o_node
        o_set_node.content = o_par_set_node.content.merge(o_set_node.content) 
      end
      
      o_job = create_job(o_set_node.node_height, o_set_node.content, @log_file)
      o_job.node = o_node
      o_node.content = o_job
      o_root_job = o_job if o_node.is_root?
    end
    
    return o_root_job
  end
  
  def create_job(n_node_height, h_settings, s_log_file)
  
    case
    when n_node_height == 1 && h_settings["Command"] == "Prevail8.exe" # TODO: check more options, use regular expression
      
      raise "Command undefined" unless h_settings.key? "Command"
      raise "User name undefined" unless h_settings.key? "User"
      raise "Program undefined" unless h_settings.key? "Program"
      raise "Directory undefined" unless h_settings.key? "Directory"
      
      s_cmd = h_settings["Command"]
      s_user = h_settings["User"]
      s_prg = h_settings["Program"]
      
      o_job = ScriptBasicJob.new()
      o_job.log_file = s_log_file
      
      a_args = Array.new()
      h_settings.each do |s_key, s_value|
        unless @reserved_keywords.include?(s_key)
          a_args << "#{s_key}='#{s_value}'"
        end
      end
      
      # prevail always expects arg
      raise "Argument not found" if a_args.empty?
     
      o_job.log_file = s_log_file
      o_job.exec_cmd = %Q{#{s_cmd} #{s_user} #{s_prg} "#{a_args.join(" ")}"}
      o_job.exec_lbl = h_settings["Label"]
      o_job.work_dir = h_settings["Directory"]
      
    when n_node_height == 1
    
      raise "Command undefined" unless h_settings.key? "Command"
      raise "Directory undefined" unless h_settings.key? "Directory"
      
      o_job = ScriptBasicJob.new()
      o_job.log_file = s_log_file
      o_job.exec_cmd = %x{#{s_cmd} 2>&1}
      o_job.exec_lbl = h_settings["Label"]
      o_job.work_dir = h_settings["Directory"]  
      
    when h_settings["Parallel"]
      o_job = ScriptParallelJob.new()
    else
      o_job = ScriptSerialJob.new()
    end
    
    return o_job
  end

end


class ScriptSerialJob
  include SerialJobbable
end

class ScriptParallelJob
  include ParallelJobbable
end

class ScriptBasicJob
  include BasicJobbable
  include TxtJobLoggable
  
  attr_accessor :exec_lbl
  
  def before_run()
    write_log("INFO", "#{@exec_lbl} started")
  end
  
  def after_run(s_result)
    write_log("DEBUG", @exec_cmd)
    write_log("INFO", s_result) 
    write_log("INFO", "#{@exec_lbl} finished")
  end
end

o_runner = ScriptRunner.new()
o_job = o_runner.setup(ARGV[0])
o_runner.run_script(o_job)

