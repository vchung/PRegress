require 'yaml'
require 'tree'
require 'bin/txt_job_loggable'
require 'bin/job_runner'

class ScriptRunner

  attr_accessor :reserved_keywords
  attr_accessor :cur_node_id
  
  def initialize()
    @cur_node_id = 0
    @reserved_keywords = ["Command", "Directory", "Program", "User", "Serial", "Parallel", "Label"]
  end

  def run_script(s_yaml_file)
    raise "Yaml file name is not provided" if s_yaml_file.nil?
    
    h_config = YAML.load_file("app/#{s_yaml_file}.yml")
    s_log_file = File.join(Dir.pwd, "log", "#{s_yaml_file}.log")
    o_root_node = create_node("Root")
    parse_script(o_root_node, h_config)
    process_settings(o_root_node)
    execute_jobs(o_root_node, s_log_file)
  end
  
  def parse_script(o_node, h_settings)
    h_settings.each do |s_key, x_val|
      if x_val.kind_of? Hash # subtask
        o_child_node = create_node(s_key, o_node)
        parse_script(o_child_node, x_val)
      else # settings
        create_node(s_key, o_node, [s_key, x_val])
      end
    end
  end
  
  def create_node(s_label, o_parent=nil, o_content=nil)
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
  
  def process_settings(o_root_node)
    # remove settings node
    # all settings nodes are leaf nodes
    
    # 1. collapse leaf nodes, store settings in parent nodes' content
    a_leaf_nodes = Array.new()
    o_root_node.each_leaf do |o_node|
      o_parent = o_node.parent()
      o_parent.content[o_node.content[0]] = o_node.content[1]
      a_leaf_nodes << o_node
    end
    
    # 2. remove leaf nodes
    a_leaf_nodes.each do |o_node|
      o_node.remove_from_parent!()
    end
    
  end
  
  def execute_jobs(o_root_node, s_log_file)
    o_root_job = nil
    o_root_node.each do |o_node|
      
      unless o_node.is_root?
        o_node.content = o_node.parent.content.merge(o_node.content)
      end
      h_settings = o_node.content
      case
      when o_node.is_leaf?
        o_job = ScriptBasicJob.new()
        o_job.log_file = s_log_file
        
        s_cmd = h_settings["Command"]
        
        if s_cmd == "Prevail8.exe"
          s_user = h_settings["User"]
          s_prg = h_settings["Program"]
          
          a_args = Array.new()
          h_settings.each do |s_key, s_value|
            unless @reserved_keywords.include?(s_key)
              a_args << "#{s_key}='#{s_value}'"
            end
          end
          
          o_job.exec_cmd = %Q{#{s_cmd} #{s_user} #{s_prg} "#{a_args.join(" ")}"}
        else
          o_job.exec_cmd = s_cmd
        end
        
        # replace settings with job
        o_node.content = o_job 
      when h_settings["Parallel"]
        o_job = ScriptParallelJob.new()
        o_job.exec_cmd = ""
      else # default to serial
        o_job = ScriptSerialJob.new()
        o_job.exec_cmd = ""
      end
      
      if o_node.is_root? 
        o_root_job = o_job
      end
      o_job.node = o_node
      o_job.exec_lbl = h_settings["Label"]
      o_job.work_dir = h_settings["Directory"]
      puts "#{o_job.exec_lbl}, #{o_job.exec_cmd}"
    end
    
    o_root_job.node.print_tree
    o_root_job.run()
    
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
  
  def before_run()
    write_log("INFO", "#{@exec_lbl} started")
  end
  
  def after_run(s_result)
    write_log("DEBUG", @exec_cmd)
    write_log("INFO", s_result) 
    write_log("INFO", "#{@exec_lbl} finished")
  end
end

ScriptRunner.new().run_script(ARGV[0])

