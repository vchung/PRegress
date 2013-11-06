require 'fileutils'
require 'yaml'

o_ser_conn = YAML.load_file('app/connection.yml')
c_jar_path = o_ser_conn['jar_path']

puts %x{warble jar}

FileUtils.mv 'pregress.jar', c_jar_path