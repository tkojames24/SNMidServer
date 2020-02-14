#! /bin/sh

#-----------------------------------------------------------------------------
# This script launches the Mid Installer wizard.
# The wizard will help to configure some of configurable elements,
# test your configuration, show various log files and 
# optionally start your MID server / service by calling the start.sh script.
#----------------------------------------------------------------------------


jre/bin/java -cp "lib/mid-installer.jar:lib/*" com.service_now.mid.installer.InstallerUI

