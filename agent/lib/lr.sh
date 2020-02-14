#!/bin/sh
#
# Service-now.com Long Running Script Wrapper
#

RUNDIR=".run.%SSH_LONG_ID%"
TMPDIR="/tmp/$RUNDIR"

mkdir $TMPDIR
cd $TMPDIR
umask 0077 # Let's keep the files we create to ourselves

####################
# Create 'stub2' script
####################

sed 's/^   //' >stub2 << 'MARKITEIGHTDUDE'
   #!/bin/sh
   #
   
   TMPDIR=`pwd`
   touch running
   sh ./command
   echo $?
   cd $TMPDIR
   rm -f running
MARKITEIGHTDUDE

####################
# Create 'command' script
####################

sed 's/^   //' >command << 'MARKITEIGHTDUDE'
   #!/bin/sh
   #
   TMPDIR=`pwd`
   %SNCCOMMAND%
MARKITEIGHTDUDE

####################
# Create 'complete' script
####################

sed 's/^   //' >complete << 'MARKITEIGHTDUDE'
   #!/bin/sh
   #
   SEPARATOR="XXX.run.%SSH_LONG_ID%.XXX"

   case "$0" in
       "/"*)
           TMPDIR="`dirname $0`" ;;
       *)
           TMPDIR="`pwd`"/"`dirname $0`" ;;
   esac

   STATUS=`tail -1 $TMPDIR/nohup.out`

   sed '$d' < $TMPDIR/nohup.out
   echo $SEPARATOR
   cat $TMPDIR/nohup.out2

   rm -f $TMPDIR/nohup.out2
   rm -f $TMPDIR/nohup.out
   rm -f $TMPDIR/stub2
   rm -f $TMPDIR/complete
   rm -f $TMPDIR/command
%ADDITIONALFILES_REMOVE%
   rmdir $TMPDIR
   exit $STATUS
MARKITEIGHTDUDE

####################
# Create additional scripts
####################

%ADDITIONALFILES_ADD%

##

RESULT=`nohup sh ./stub2 1>$TMPDIR/nohup.out 2>$TMPDIR/nohup.out2 3>/dev/null &`
sleep 1
echo "sncrun:$RUNDIR"
exit 0
