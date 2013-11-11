require 'open-uri'
require 'java'
require 'net/smtp'
require 'yaml'
require 'tree'
require 'bin/job_info'
require 'bin/job_runner'
require 'bin/job_logger'

java_import 'oracle.jdbc.OracleDriver'
java_import 'java.sql.DriverManager'
java_import 'java.sql.ResultSet'

# TODO: need to handle mdlstats save settings issue (GSTATS)

class PRegress
  
  def initialize()
    @o_ser_conn = YAML.load_file('app/connection.yml')
    @c_ora_url = @o_ser_conn['ora_url']
    @c_ora_user = @o_ser_conn['ora_user']
    @c_ora_pass = @o_ser_conn['ora_pass']
	  @c_app_folder = @o_ser_conn['app_folder']
    @o_conn = nil
    
    oradriver = OracleDriver.new()
    DriverManager.registerDriver(oradriver)
    @o_conn = DriverManager.get_connection(@c_ora_url, @c_ora_user, @c_ora_pass)
	
    @o_logger = OraJobLogger.new()
    @o_logger.o_conn = @o_conn
  
    # create connection to vfp table
    s_driver = "sun.jdbc.odbc.JdbcOdbcDriver"
    s_url = %Q{jdbc:odbc:Driver={#{@o_ser_conn["vfp_driver"]}};SourceType=DBF;SourceDB=#{@o_ser_conn["custom_folder"]};}
    @o_custom_conn = DriverManager.getConnection(s_url, "", "")
  end
  
  def run_routine(n_run_id, n_root_node_id)
  
    c_query = %Q{
      select j.job_id, t.node_id, t.parent_node_id, t.node_name, t.node_type, sys_connect_by_path(t.node_id, '>') path,
        upper(j.prg_name) prg_name, j.settings_label, j.settings_xml, upper(j.user_name) user_name
      from perfjobtree t
      left join perfjobs j on j.job_id = t.job_id
      start with t.node_id = :1
      connect by prior t.node_id = t.parent_node_id
    }
  
    o_stmt = @o_conn.prepare_statement(c_query)
    o_stmt.set_int(1, n_root_node_id)
    o_rs = o_stmt.execute_query()
	
    h_nodes = Hash.new()
    o_root_node = nil
    
    while o_rs.next()
    
      n_job_id = o_rs.get_int("job_id")
      c_prg_name = o_rs.get_string("prg_name")
      c_settings_label = o_rs.get_string("settings_label")
      c_settings_xml = o_rs.get_string("settings_xml")
      c_user_name = o_rs.get_string("user_name")
      c_node_type = o_rs.get_string("node_type")
      n_node_id = o_rs.get_int("node_id")
      n_parent_node_id = o_rs.get_int("parent_node_id")
      
      add_settings(c_prg_name, c_user_name, c_settings_xml, n_node_id) unless n_job_id.nil? or n_job_id == 0
      
      # run prevail 
      
      s_exec_cmd = %Q{Prevail8.exe #{c_user_name} #{c_prg_name} "SettingLabel='#{c_settings_label}'"}
      s_work_dir = @c_app_folder
      s_job_type = c_node_type
      
      o_job_info = JobInfo.new()
      o_job_info.exec_cmd = s_exec_cmd
      o_job_info.work_dir = s_work_dir
      o_job_info.job_type = s_job_type
      o_job_info.run_id = n_run_id
      o_job_info.job_id = n_job_id
      o_job_info.node_id = n_node_id
      
      o_node = Tree::TreeNode.new(n_node_id.to_s, o_job_info)
      h_nodes[n_node_id] = o_node

      if n_parent_node_id.nil? or n_parent_node_id == 0 ## TODO:
        o_root_node = o_node
      else
        o_parent_node = h_nodes[n_parent_node_id]
        o_parent_node << o_node
      end
      
    end
    
    JobRunner.run_jobs(o_root_node, @o_logger)
    
  end
  
  def clear_settings()
    # delete all saved setting for routine and user
    c_del_sql = %Q{delete from custprop where property like ?}
    o_del_stmt = @o_custom_conn.prepare_statement(c_del_sql)
    o_del_stmt.set_string(1, "%SETTINGS%")
    n_del_cnt = o_del_stmt.execute_update()
    @o_custom_conn.commit()
  end
  
  def add_settings(c_prg_name, c_user_name, c_settings_xml, n_node_id)
  
    # insert new settings
    # TODO: not sure whether to use job_id or node_id
    c_ins_sql = %Q{insert into custprop (scope, property, userid, value, memovalue, lock, type) values (?, ?, ?, ?, ?, ?, ?)}
    o_ins_stmt = @o_custom_conn.prepare_statement(c_ins_sql)
    o_ins_stmt.set_string(1, c_prg_name)
    o_ins_stmt.set_string(2, "SETTINGS.#{n_node_id.to_s.rjust(3, "0")}")
    o_ins_stmt.set_string(3, c_user_name)
    o_ins_stmt.set_string(4, "")
    o_ins_stmt.set_string(5, c_settings_xml)
    o_ins_stmt.set_string(6, "")
    o_ins_stmt.set_string(7, "C")
    n_ins_cnt = o_ins_stmt.execute_update()
    @o_custom_conn.commit()
    
  end
  
  def get_runlabel(n_root_node_id) # ex: 1, 8, 12
  
    # get run_id
    c_query = %Q{select seq_run.nextval run_id from dual}
    o_stmt = @o_conn.create_statement()
    o_rs = o_stmt.execute_query(c_query)
    o_rs.next()
    n_run_id =o_rs.get_int("run_id")
    
    # log run start time
    t_report_start = Time.now
    c_report_start = t_report_start.strftime("%m/%d/%Y %H:%M:%S")
    c_run_label = ARGV[0]
    c_sql = %Q{insert into perfruns (run_id, run_label, start_time) 
             values (:1, :2, to_date(:3,'MM/DD/YYYY HH24:MI:SS'))}
    c_insert_stmt = @o_conn.prepare_statement(c_sql)
    c_insert_stmt.set_int(1, n_run_id)
    c_insert_stmt.set_string(2, c_run_label)
    c_insert_stmt.set_string(3, c_report_start)
    c_insert_stmt.execute()
    @o_conn.commit()
    
    clear_settings()
    
    run_routine(n_run_id, n_root_node_id)
  end	
end	

class OraJobLogger < JobLogger

  attr_accessor :o_conn

  def log_job_start(o_job_info)
    # insert
    t_run_start = Time.now
    c_run_start = t_run_start.strftime("%m/%d/%Y %H:%M:%S")
    
    c_sql = %Q{insert into perfrunlogs (log_id, run_id, node_id, start_time) 
               values (seq_report.nextval, :1, :2, to_date(:3,'MM/DD/YYYY HH24:MI:SS'))
    }

    o_stmt = @o_conn.prepare_statement(c_sql)
    o_stmt.set_int(1, o_job_info.run_id)
    o_stmt.set_int(2, o_job_info.node_id)
    o_stmt.set_string(3, c_run_start)
    o_stmt.execute()
    
    @o_conn.commit()
  end
  
  def log_job_end(o_job_info)
    # update
    t_run_end = Time.now
    c_run_end = t_run_end.strftime("%m/%d/%Y %H:%M:%S")
    
    c_sql = %Q{update perfrunlogs set end_time = to_date(:1,'MM/DD/YYYY HH24:MI:SS')
               where run_id = :2 and node_id = :3
    }

    o_stmt = @o_conn.prepare_statement(c_sql)
    o_stmt.set_string(1, c_run_end)
    o_stmt.set_int(2, o_job_info.run_id)
    o_stmt.set_int(3, o_job_info.node_id)
    o_stmt.execute()
    
    @o_conn.commit()
  end


end

o_test = PRegress.new()
o_test.get_runlabel(1)
