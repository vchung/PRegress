

class JobInfo

  attr_accessor :exec_cmd
  attr_accessor :work_dir
  attr_accessor :job_type # serial or parallel
  
  attr_accessor :job_id # pregress only
  attr_accessor :run_id # pregress only
  attr_accessor :node_id # pregress only
  
end