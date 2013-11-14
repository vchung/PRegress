
shared_examples_for "job tree" do

  it "should populate node, exec_cmd, work_dir attributes if it is leaf node" do 
    @o_root_job.node.each_leaf do |o_node|
      o_job = o_node.content
      o_job.should_not be_nil
      o_job.should be_a_kind_of BasicJobbable
      o_job.exec_cmd.should_not be_nil
      o_job.exec_cmd.should_not be_empty
      o_job.work_dir.should_not be_nil
      o_job.work_dir.should_not be_empty
    end
  end
  
  it "all the nodes' content should be job and jobs' node should be the same node" do 
    
    o_root_node = @o_root_job.node
    o_root_node.should_not be_nil
    o_root_node.should be_an_instance_of Tree::TreeNode
    o_root_node.content.should eql @o_root_job 
    
    o_root_node.each do |o_node|
    
      o_node.should_not be_nil
      o_node.should be_an_instance_of Tree::TreeNode
      
      o_job = o_node.content
      o_job.should_not be_nil
      o_job.node.should eql o_node
      
    end
  end
end