require 'open-uri'
require 'java'
require 'net/smtp'
require 'yaml'

java_import 'oracle.jdbc.OracleDriver'
java_import 'java.sql.DriverManager'
java_import 'java.sql.ResultSet'

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
	
    # create connection to vfp table
    s_driver = "sun.jdbc.odbc.JdbcOdbcDriver"
    s_url = %Q{jdbc:odbc:Driver={#{@o_ser_conn["vfp_driver"]}};SourceType=DBF;SourceDB=#{@o_ser_conn["custom_folder"]};}
    @o_custom_conn = DriverManager.getConnection(s_url, "", "")
  end
  
  def update_oratable(n_job_id, c_prg_name, t_run_start, t_run_end, n_run_id)
    c_run_start = t_run_start.strftime("%m/%d/%Y %H:%M:%S")
    c_run_end = t_run_end.strftime("%m/%d/%Y %H:%M:%S")
	
    c_query = %Q{select seq_report.nextval from dual}
    o_stmt = @o_conn.create_statement()
    o_rs = o_stmt.execute_query(c_query)
    o_rs.next()
    n_log_id =o_rs.get_int("nextval")
	
    c_sql = %Q{insert into perfrunlogs (log_id, job_id, start_time, end_time, run_id) 
	          values (seq_report.nextval, :1, to_date(:2,'MM/DD/YYYY HH24:MI:SS'), to_date(:3,'MM/DD/YYYY HH24:MI:SS'), :4)}

    c_insert_stmt = @o_conn.prepare_statement(c_sql)
    c_insert_stmt.set_int(1, n_job_id)
    c_insert_stmt.set_string(2, c_run_start)
    c_insert_stmt.set_string(3, c_run_end)
    c_insert_stmt.set_int(4, n_run_id)
	
    c_insert_stmt.execute()
    @o_conn.commit()
  end
  
  def run_routine(n_run_id)
    c_query = %Q{select job_id, upper(prg_name) prg_name, settings_label, settings_xml, upper(user_name) user_name from perfjobs order by job_id}
    o_stmt = @o_conn.create_statement()
    o_rs = o_stmt.execute_query(c_query)
	
    while o_rs.next()
    
      n_job_id = o_rs.get_int("job_id")
      c_prg_name = o_rs.get_string("prg_name")
      c_settings_label = o_rs.get_string("settings_label")
      c_settings_xml = o_rs.get_string("settings_xml")
      c_user_name = o_rs.get_string("user_name")
      
      setup_settings(c_prg_name, c_user_name, c_settings_xml)
      
      # run prevail 
      t_run_start = Time.now()
      Dir.chdir(@c_app_folder) do 
        run_cmd = %x{Prevail8.exe #{c_user_name} #{c_prg_name} "SettingLabel='#{c_settings_label}'"}
      end
      t_run_end = Time.now()
	  
      update_oratable(n_job_id, c_prg_name, t_run_start, t_run_end, n_run_id)
    end    
  end
  
  def setup_settings(c_prg_name, c_user_name, c_settings_xml)
  
    # 1. delete all saved setting for routine and user
    c_del_sql = %Q{delete from custprop where scope = ? and property like ? and userid = ?}
    o_del_stmt = @o_custom_conn.prepare_statement(c_del_sql)
    o_del_stmt.set_string(1, c_prg_name)
    o_del_stmt.set_string(2, "%SETTINGS%")
    o_del_stmt.set_string(3, c_user_name)
    n_del_cnt = o_del_stmt.execute_update()
    @o_custom_conn.commit()
    
    puts "n_del_cnt: #{n_del_cnt}"
 
    # 2. insert new settings
    c_ins_sql = %Q{insert into custprop (scope, property, userid, value, memovalue, lock, type) values (?, ?, ?, ?, ?, ?, ?)}
    o_ins_stmt = @o_custom_conn.prepare_statement(c_ins_sql)
    o_ins_stmt.set_string(1, c_prg_name)
    o_ins_stmt.set_string(2, "SETTINGS.001")
    o_ins_stmt.set_string(3, c_user_name)
    o_ins_stmt.set_string(4, "")
    o_ins_stmt.set_string(5, c_settings_xml)
    o_ins_stmt.set_string(6, "")
    o_ins_stmt.set_string(7, "C")
    n_ins_cnt = o_ins_stmt.execute_update()
    @o_custom_conn.commit()
    
    puts "n_ins_cnt: #{n_ins_cnt}"
  end
  
  def get_runlabel()
    c_query = %Q{select seq_run.nextval from dual}
    o_stmt = @o_conn.create_statement()
    o_rs = o_stmt.execute_query(c_query)
    o_rs.next()
    n_run_id =o_rs.get_int("nextval")
  
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
    
    run_routine(n_run_id)
  end	
end	

oTest = PRegress.new()
oTest.get_runlabel()
