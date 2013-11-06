require 'yaml'
require 'open-uri'
require 'java'
require 'gmail'
require 'net/smtp'

java_import 'oracle.jdbc.OracleDriver'
java_import 'java.sql.DriverManager'

class PerfReport
  
  def initialize()
    @c_work_dir       = Dir.pwd
    @d_end_date       = Time.new(Date.today.year, Date.today.month, Date.today.day)
    @d_begin_date     = Time.new(Date.today.year, Date.today.month, Date.today.day)- (60*60*24*7) 
    @o_ser_conn = YAML.load_file('connection.yml')
    @c_ora_url = @o_ser_conn['ora_url']
    @c_ora_user = @o_ser_conn['ora_user']
    @c_ora_pass = @o_ser_conn['ora_pass']
    @o_conn = nil
    @o_gmail_acct = @o_ser_conn['gmail_acct']
    @o_gmail_pass = @o_ser_conn['gmail_pass']
    
    oradriver = OracleDriver.new()
    DriverManager.registerDriver(oradriver)
    @o_conn = DriverManager.get_connection(@c_ora_url, @c_ora_user, @c_ora_pass)
	
  end
  
  def send_report()
    c_html_settings = get_html_settings()
    c_greeting_body = construct_greeting()
    c_report_body = get_report()
    c_subject_line = "Prevail8 Performance Report"
    c_recipients_list_all = get_recipients()
	
    Gmail.new(@o_gmail_acct, @o_gmail_pass) do |gmail|
      gmail.deliver do
        to c_recipients_list_all
        subject c_subject_line
        html_part do
          content_type 'text/html; charset=UTF-8'
          body c_greeting_body + c_html_settings + c_report_body
        end
      end
    end
  end
  
  def get_html_settings()
    c_msg = "<span style=\" font-family: Courier; font-size: 12px; color: #000000;\">"
  end 
  
  def construct_greeting()
    c_msg =  "<header>"
    c_msg += "<h2>Weekly Performance Analysis </h2>"
    c_msg += "<h3>#{@d_begin_date.strftime("%m/%d/%Y")} to #{@d_end_date.strftime("%m/%d/%Y")}</h3>"
    c_msg += "</header>"
  end
  
  def get_recipients()
    c_recipients_list = ""
    open("#{@c_work_dir}/recipients.txt").map do |line|
    c_recipients_list = "#{line.strip},"
    end  
  end
	
  def get_report()
    c_run_label = ARGV[0]
    c_query = %Q{select pj.prg_name, target.target_run_time, baseline.baseline_run_time, (target.target_run_time - baseline.baseline_run_time) as diff 
                 from (select pl.job_id, ROUND((pl.end_time - pl.start_time)*60*60*24) as target_run_time, pl.run_id from perfrunlogs pl inner join perfruns pr on pl.run_id = pr.run_id where pr.run_label = '#{c_run_label}') target
                 inner join (select pl.job_id, ROUND((pl.end_time - pl.start_time)*60*60*24) as baseline_run_time, pl.run_id from perfrunlogs pl where pl.is_baseline = 'Y') baseline on baseline.job_id = target.job_id
                 inner join perfjobs pj on target.job_id = pj.job_id
                 order by diff desc
				        }
	
	  o_stmt = @o_conn.create_statement()
	  o_rs = o_stmt.execute_query(c_query)
	  s_msg = %Q{<table border="1" cellpadding="10" cellspacing="0">
		           <caption><em>Prevail #{c_run_label} Performace Result</em></caption>
		           <tr align="center">
		           <td bgcolor="#FFCC99"><b>Program<br>Name</b></td>
		           <td bgcolor="#FFCC99"><b>Baseline<br>(sec)</b></td>
		           <td bgcolor="#FFCC99"><b>Current&nbsp;Run<br>Time(sec)</b></td>
		           <td bgcolor="#FFCC99"><b>Time<br>Efficiency</b></td>
		           <td bgcolor="#FFCC99"><b>Performance<br>Result</b></td>	
		           </tr>
	            }
	  while o_rs.next()
	    c_prg_name = o_rs.get_string("prg_name")
	    n_baseline = o_rs.get_float("baseline_run_time")
	    n_target_time = o_rs.get_float("target_run_time")
	    n_diff_time = (n_target_time / n_baseline).round(2)
	    n_percentage = ((n_target_time - n_baseline)/ (n_baseline))*100
	    s_msg += %Q{<tr align="center">
		              <td>#{c_prg_name}</td>
		              <td>#{n_baseline.round(2)}</td>
		              <td>#{n_target_time.round(2)}</td>
	               }

	    if n_percentage > 10 
	      s_msg += %Q{<td><font color=#FF0000"><b>#{n_diff_time.round(2)} times slower</b></font></td>
		                <td><font color=#FF0000"><b>declines: #{n_percentage.abs.ceil}%</b></font></td>
		                </tr>		 
	                 }
      elsif n_percentage <= 0 
	      s_msg += %Q{<td><font color=#009900"><b>#{((1-n_diff_time)+1).round(2)} times faster</b></font></td>
		                <td><font color=#009900"><b>improves: #{n_percentage.abs.ceil}%</b></font></td>
		                </tr>
	                 }
	    else 
		    s_msg += %Q{<td><font color=#FFCC00"><b>#{n_diff_time.round(2)} times slower</b></font></td>
		                <td><font color=#FFCC00"><b>declines: #{n_percentage.abs.ceil}%</b></font></td>
		                </tr>
	                 } 
	    end	  
    end  
	  return s_msg
  end
end	
	
oReport = PerfReport.new()
oReport.send_report()	
	
	