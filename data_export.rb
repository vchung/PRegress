require 'open-uri'
require 'java'
require 'net/smtp'
require 'yaml'

java_import 'oracle.jdbc.OracleDriver'
java_import 'java.sql.DriverManager'

class PerfTest
  
  attr :c_work_dir
  
  def initialize()
  @c_work_dir = Dir.pwd
  @o_ser_conn = YAML.load_file('connection.yml')
  @c_ora_url = @o_ser_conn['ora_url']
  @c_ora_user = @o_ser_conn['ora_user']
  @c_ora_pass = @o_ser_conn['ora_pass']
  @o_conn = nil
    
  oradriver = OracleDriver.new()
  DriverManager.registerDriver(oradriver)
  @o_conn = DriverManager.get_connection(@c_ora_url, @c_ora_user, @c_ora_pass)
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
  
  def run_routine(n_run_id, c_report_start)
  Dir.chdir(@c_work_dir)
  c_query = %Q{select job_id, prg_name, settings_label from perfjobs order by job_id}
  o_stmt = @o_conn.create_statement()
  o_rs = o_stmt.execute_query(c_query)
  while o_rs.next()
    n_job_id = o_rs.get_int("job_id")
    c_prg_name = o_rs.get_string("prg_name")
    c_settings_label = o_rs.get_string("settings_label")
    t_run_start = Time.now()
    run_cmd = %x{Prevail8.exe ARETE #{c_prg_name} "SettingLabel='#{c_settings_label}'"}
    t_run_end = Time.now()
	  
    update_oratable(n_job_id, c_prg_name, t_run_start, t_run_end, n_run_id)
  end
  c_run_label = ARGV[0]
  t_report_end = Time.now
  c_report_end = t_report_end.strftime("%m/%d/%Y %H:%M:%S")
  c_sql = %Q{insert into perfruns (run_id, run_label, start_time, end_time) 
             values (:1, :2, to_date(:3,'MM/DD/YYYY HH24:MI:SS'), to_date(:4,'MM/DD/YYYY HH24:MI:SS'))}
  c_insert_stmt = @o_conn.prepare_statement(c_sql)
  c_insert_stmt.set_int(1, n_run_id)
  c_insert_stmt.set_string(2, c_run_label)
  c_insert_stmt.set_string(3, c_report_start)
  c_insert_stmt.set_string(4, c_report_end)
  c_insert_stmt.execute()
  @o_conn.commit()
  end
  def get_runlabel()
  t_report_start = Time.now
  c_report_start = t_report_start.strftime("%m/%d/%Y %H:%M:%S")
	
  c_query = %Q{select seq_run.nextval from dual}
  o_stmt = @o_conn.create_statement()
  o_rs = o_stmt.execute_query(c_query)
  o_rs.next()
  n_run_id =o_rs.get_int("nextval")
	
  run_routine(n_run_id, c_report_start)
  end	
end	

#calculate run_time :select log_id, (to_char(end_time, 'SS')- to_char(start_time, 'SS')) as run_time from perfrunlogs order by log_id desc;
oTest = PerfTest.new()
oTest.get_runlabel()