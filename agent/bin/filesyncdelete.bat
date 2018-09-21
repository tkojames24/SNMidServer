@ECHO OFF

REM First argument is the service name to wait for a complete stop.
REM The rest of the arguments are the list of files to be deleted.

REM Redirect stdout and stderr to log file
> logs\filesyncdelete.log 2>&1 (

	REM Call routine to make sure the service is stopped
	call :wait_svc_stopped %1

	REM Attempt to delete all files passed in as arguments, ignoring 1st argument
	for %%f in (%*) do (
		if not %%f == %1 (
			REM Call routine to delete a single file
			call :delete_file %%f
		)
	)

	REM Restart mid server
	bin\mid.bat start
)
goto :eof


REM Routine to wait for the service to stop
:wait_svc_stopped
echo waiting for service %1 to stop
for /l %%t in (1,1,120) do (
	echo    try %%t
	REM Find the line with STATE and grab the status from the 3rd token
	REM E.g.
	REM         STATE              : 1  STOPPED
	REM         STATE              : 4  RUNNING
	for /f "tokens=3 delims=: " %%s in ('sc query %1 ^| findstr "        STATE"') do (
		echo        %%s
		if /i %%s == stopped (
			echo        good to go
			goto :eof
		)
	)
	ping -n 2 127.0.0.1>nul
)
goto :eof


REM Routine to attempt to delete a single file
:delete_file
echo attempt to delete %1
for /l %%t in (1,1,10) do (
	echo    try %%t
	del %1
	if not exist %1 (
		echo        file %1 deleted
		goto :eof
	)
	echo        file %1 still exists
	ping -n 2 127.0.0.1>nul
)
goto :eof