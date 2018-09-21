#! /bin/sh

#-----------------------------------------------------------------------------
# This script launches the Mid Installer wizard.
# The wizard will help to configure some of configurable elements,
# test your configuration, show various log files and 
# optionally start your MID server / service by calling the start.sh script.
#----------------------------------------------------------------------------

##########################################################################################################
# Check which java command to use, if jre exist in agent folder, use this one.
# Otherwise, check the version of JAVA_HOME, if it's later than 1.8, use it.
# Otherwise, check for java in PATH, if it's later than 1.8, use it.
# Otherwise, give an error indicating that user should manually install java.
##########################################################################################################

# Check java version.
# This function takes one parameter which should be the path to a java command.
# It will check the version of this java, if it's 1.8 or later return 0, else return 1.
checkJavaVersion() {
        version=$($1 -version 2>&1 | sed -n ';s/.* version "\(.*\)\.\(.*\)\..*"/\1\2/p;')
        display_version=$($1 -version 2>&1 | sed -n ';s/.* version "\(.*\)"/\1/p;')

        if [ "$version" -eq "18" ]
        then
            return 0
        else
            return 1
        fi
}

if [ -d "jre" ] ; then
    JAVA_COMMAND=jre/bin/java
elif grep "^[^[:space:]*#]" conf/wrapper-override.conf | grep -q 'wrapper.java.command=' && checkJavaVersion `grep "^[^[:space:]*#]" conf/wrapper-override.conf | grep "wrapper.java.command=" conf/wrapper-override.conf | cut -d '=' -f2`
then
    echo "wrapper.java.command found in wrapper-override.conf"
    JAVA_COMMAND=`grep "^[^[:space:]*#]" conf/wrapper-override.conf | grep "wrapper.java.command=" conf/wrapper-override.conf | cut -d '=' -f2`
elif [ $JAVA_HOME ] && checkJavaVersion $JAVA_HOME/bin/java ; then
    echo "Found valid JRE from JAVA_HOME ($JAVA_HOME)"
    JAVA_COMMAND=$JAVA_HOME/bin/java
elif which java 2>&1 >/dev/null && checkJavaVersion `which java` ; then
    echo "Found valid JRE from current running environment"
    JAVA_COMMAND=`which java`
else
    echo "Can't find a valid jre on this machine, please install jre 1.8.0_152 or later"
    echo "Press enter key to continue..."
    read _
    exit
fi

echo "Using java command: $JAVA_COMMAND"

$JAVA_COMMAND -cp "lib/mid-installer.jar:lib/*" com.service_now.mid.installer.InstallerUI

