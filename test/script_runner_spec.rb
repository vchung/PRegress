require 'bin/script_runner'
require 'test/runner_spec'

describe ScriptRunner do

  before(:each) do 
    @o_runner = ScriptRunner.new()
  end
  
  context "basic check" do 
  
    # TODO: it_behaves_like "job tree"
  
    it "should throw error if yaml file name is not provided" do 
      expect { 
        @o_runner.setup() 
      }.to raise_error
      
      expect { 
        @o_runner.setup("") 
      }.to raise_error
    end
  
  end

  context "basic parallel batch" do 
  
    it "should genfcst-parallel " do 
      s_yaml_file_basename = "genfcst-parallel"
      @o_root_job = @o_runner.setup(s_yaml_file_basename)
      verify_tree(s_yaml_file_basename)
    end
    
    it "should parallel " do 
      s_yaml_file_basename = "genfcst-parallel-denormalized"
      @o_root_job = @o_runner.setup(s_yaml_file_basename)
      verify_tree(s_yaml_file_basename)
    end
    
    it "should genfcst-parallel-semi-normalized " do 
      s_yaml_file_basename = "genfcst-parallel-semi-normalized"
      @o_root_job = @o_runner.setup(s_yaml_file_basename)
      verify_tree(s_yaml_file_basename)
    end
    
    it "should genfcst-parallel-default" do 
      # if serial/parallel is not defined, it should default to serial
      s_yaml_file_basename = "genfcst-parallel-default"
      @o_root_job = @o_runner.setup(s_yaml_file_basename)
      verify_tree(s_yaml_file_basename)
    end
    
    def verify_tree(s_yaml_file_basename)
    
      s_log_file = File.join(Dir.pwd, "log", "#{s_yaml_file_basename}.log")
    
      o_node = @o_root_job.node
      o_node.children.length.should eq 2
      o_job = o_node.content
      o_job.should be_a_instance_of ScriptSerialJob
      o_job.should be_a_kind_of SerialJobbable
        
      o_node = @o_root_job.node[0] 
      o_node.is_leaf?.should be_true
      o_job = o_node.content
      o_job.should be_a_instance_of ScriptBasicJob
      o_job.should be_a_kind_of BasicJobbable
      o_job.exec_cmd.should eq %Q{Prevail8.exe NYC gDtlRollUp "SettingsLabel='WHSE_BOUND_BROOK'"}
      o_job.work_dir.should eq "d:/Prevail8"
      o_job.exec_lbl.should eq "Roll up Detail Sales History"
      o_job.log_file.should eq s_log_file
      
      o_genfcst_node = @o_root_job.node[1] 
      o_genfcst_node.is_leaf?.should be_false
      o_genfcst_node.children.length.should eq 3
      o_job = o_genfcst_node.content
      o_job.should be_a_instance_of ScriptParallelJob
      o_job.should be_a_kind_of ParallelJobbable
      
      o_node = o_genfcst_node[0]
      o_node.is_leaf?.should be_true
      o_job = o_node.content
      o_job.should be_a_instance_of ScriptBasicJob
      o_job.should be_a_kind_of BasicJobbable
      o_job.exec_cmd.should eq %Q{Prevail8.exe NYC gMdlFcstx "SettingsLabel='CHAN_11'"}
      o_job.work_dir.should eq "d:/Prevail8"
      o_job.exec_lbl.should eq "Generate Forecasts (Channel 11)"
      o_job.log_file.should eq s_log_file
      
      o_node = o_genfcst_node[1]
      o_node.is_leaf?.should be_true
      o_job = o_node.content
      o_job.should be_a_instance_of ScriptBasicJob
      o_job.should be_a_kind_of BasicJobbable
      o_job.exec_cmd.should eq %Q{Prevail8.exe NYC gMdlFcstx "SettingsLabel='CHAN_12'"}
      o_job.work_dir.should eq "d:/Prevail8"
      o_job.exec_lbl.should eq "Generate Forecasts (Channel 12)"
      o_job.log_file.should eq s_log_file
      
      o_node = o_genfcst_node[2]
      o_node.is_leaf?.should be_true
      o_job = o_node.content
      o_job.should be_a_instance_of ScriptBasicJob
      o_job.should be_a_kind_of BasicJobbable
      o_job.exec_cmd.should eq %Q{Prevail8.exe NYC gMdlFcstx "SettingsLabel='CHAN_13'"}
      o_job.work_dir.should eq "d:/Prevail8"
      o_job.exec_lbl.should eq "Generate Forecasts (Channel 13)"
      o_job.log_file.should eq s_log_file
    end

    it "should throw error if user or program or parameter is not found when prevail8 job"
    
    it "should log "
  end
end