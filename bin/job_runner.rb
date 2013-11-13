require 'java'

java_import 'java.lang.Runnable'


module Jobbable
  
  attr_accessor :exec_lbl
  attr_accessor :exec_cmd
  attr_accessor :work_dir
  attr_accessor :job_type
  attr_accessor :run_id
  attr_accessor :job_id
  attr_accessor :node_id
  attr_accessor :node
  
  def before_run(); end
  
  def after_run(s_result=nil); end
  
end

module BasicJobbable
  include Runnable 
  include Jobbable
  
  def run()
    
    before_run()
    
    s_result = ""
    
    Dir.chdir(@work_dir) do 
      s_result = %x{#{@exec_cmd}}
    end  
    
    after_run(s_result)
    
  end
  
  
  
end

module SerialJobbable
  include Runnable
  include Jobbable
  
  def run()
    before_run()
    @node.children do |o_child_node|
      o_child_node.content.run()
    end
    after_run()
  end
end

module ParallelJobbable
  include Runnable
  include Jobbable
  
  def run()
    before_run()
    @node.children do |o_child_node|
      o_child_node.content.run()
    end
    after_run()
  end
  
end




