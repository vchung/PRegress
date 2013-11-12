
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
  
end

module BasicJobbable
  include Runnable 
  include Jobbable
  
  def run()
    
    before_run()
    
    Dir.chdir(@work_dir) do 
      s_result = %x{#{@exec_cmd}}
    end  
    
    after_run(s_result)
    
  end
  
  def before_run()
  end
  
  def after_run(s_result=nil)
  end
  
end

module SerialJobbable
  include Runnable
  include Jobbable
  
  def run()
    before_run()
    @node.children do |o_child_node|
      run()
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
      run()
    end
    after_run()
  end
  
end




