
require 'java'

java_import 'java.lang.Runnable'


class JobFactory
  
  def self.create_job(o_node, o_logger)
  
    o_job_info = o_node.content
    
    case
    when o_job_info.job_type == "S" 
      o_job = SerialJob.new()
    when o_job_info.job_type == "P"
      o_job = ParallelJob.new()
    else
      o_job = BasicJob.new()
    end
    
    o_job.node = o_node
    o_job.logger = o_logger
    
    return o_job
  end
  
end

class JobRunner

  def self.run_jobs(o_root_node, o_logger) # rubytree
    puts "JobRunner.run_jobs..."
    
    o_root_node.print_tree()
    
    o_job = JobFactory.create_job(o_root_node, o_logger)
    o_job.run()
  end

end

module Jobbable
  include Runnable
  
  attr_accessor :node
  attr_accessor :logger
  
  def run()
    o_job_info = @node.content
    
    @logger.log_job_start(o_job_info) 
    
    run_job()
    
    @logger.log_job_end(o_job_info) 
    
  end
  
  def run_job()
    # to-be implemented by child class
  end
  
end

class BasicJob 
  include Jobbable
  
  def run_job()
    o_job_info = @node.content
    Dir.chdir(o_job_info.work_dir) do 
      %x{#{o_job_info.exec_cmd}}
    end  
  end
  
end

class SerialJob
  include Jobbable
  
  def run_job()
    @node.children do |o_child_node|
      o_job = JobFactory.create_job(o_child_node, @logger)
      o_job.run()
    end
  end
  
end

class ParallelJob
  include Jobbable
  
  def run_job()
    @node.children do |o_child_node|
      o_job = JobFactory.create_job(o_child_node, @logger)
      o_job.run()
    end
  end
  
end




