@echo off
rem Verify if the batch file is running as admin or not
net session > nul 2>&1
if %errorLevel% EQU 0 (
    goto :admin
) else (
    goto :non_admin
)

rem If an admin user tries to stop the MID Server we stop the service using Tanuki Wrapper
:admin
bin\mid.bat stop
goto eof

rem Non admin user can stop the service
:non_admin
set _OVERRIDE_PATH="%~dp0%conf\wrapper-override.conf"
for /F "tokens=2 delims==" %%a in ( 'findstr /b "wrapper.name=" %_OVERRIDE_PATH%' ) do set _CURRENT_SERVICE=%%a
for /F "tokens=3 delims=: " %%s in ( 'sc query %_CURRENT_SERVICE% ^| findstr STATE' ) do set _SERVICE_STATUS=%%s
if [!_SERVICE_STATUS!] == [] (
	echo %_CURRENT_SERVICE% is not installed.
)
if %_SERVICE_STATUS% == RUNNING (
	sc stop %_CURRENT_SERVICE%
)
goto eof
