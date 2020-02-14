@echo off

rem -----------------------------------------------------------------------------
rem This script launch the Mid Installer wizard.
rem The wizard will help to configure some of configurable elements,
rem test your configuration, show various log files and
rem optionally start your MID server / service by calling the start.bat script.
rem -----------------------------------------------------------------------------

jre\bin\java -classpath .;lib/* com.service_now.mid.installer.InstallerUI
