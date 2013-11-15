PRegress
============
Automation Performance Regression Testing System

Preinstallation
----------------

1. download jruby from http://jruby.org/
2. copy oracle.jdbc.OracleDriver "ojdbc6.jar" to jruby > lib folder
3. install gem bundler :http://ruby.about.com/od/bundler/ss/Getting-Started-With-Bundler.htm
4. add-->  gem "rubytree" in Gemfile

How to package the code?
-------------------------

1. download jruby 1.7.4
2. gem install warbler
3. gem install zip-zip
4. create a "config" folder
5. run > warble config to generate a configuration file called "warble.rb"
6. move warble.rb under config folder
7. open warble.rb file, uncomment line 26 and make change to 
   config.java_libs += FileList["lib/*.jar"]
8. create a "lib" folder and copy oracle.jdbc.OracleDriver "ojdbc6.jar"  under the lib folder
9. add bin folder and move all the code/scripts under this folder
10. create an "app" folder and move connection.yml filer under app folder
11. run > warble jar to generate the jar file
12. run > java -jar pregress.jar to run the exe

Running Process
----------------
1. Insert log start time
2. Clear all saved settings in custprop
3. Add saved settings for jobs
4. Run routines
5. Insert log end time

Job Tree: Serial
-----------------



