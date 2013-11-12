
require 'java'

java_import 'java.lang.Runnable'


module Jobbable
  include Runnable
  
  attr_accessor :exec_cmd
  attr_accessor :work_dir
  attr_accessor :job_type
  attr_accessor :run_id
  attr_accessor :job_id
  attr_accessor :node_id
  attr_accessor :node
  
end

module BasicJobable 
  include Jobbable
  
  def run()
    before_run()
    Dir.chdir(@work_dir) do 
      %x{#{@exec_cmd}}
    end  
    after_run()
  end
  
end

module SerialJobbale
  include Jobbable
  
  def run()
    before_run()
    @node.children do |o_child_node|
      run()
    end
    after_run()
  end
end

module ParallelJobbale
  include Jobbable
  
  def run()
    before_run()
    @node.children do |o_child_node|
      run()
    end
    after_run()
  end
  
end




