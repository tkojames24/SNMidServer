@echo off

rem -----------------------------------------------------------------------------
rem This script launch the Mid Installer wizard.
rem The wizard will help to configure some of configurable elements,
rem test your configuration, show various log files and
rem optionally start your MID server / service by calling the start.bat script.
rem -----------------------------------------------------------------------------



rem #############################################################################################################
rem If bundled jre exists, use this jre, otherwise, check JAVA_HOME.
rem #############################################################################################################
IF EXIST jre (
	SET JAVA_COMMAND=jre\bin\java
	GOTO start_installer
)

FOR /f "tokens=2 delims==" %%j IN ('FINDSTR /R /C:"^ *wrapper.java.command=.*" ".\conf\wrapper-override.conf"') do SET "EXISTING_JAVA_COMMAND=%%j"

IF ["%EXISTING_JAVA_COMMAND%"] == [""] goto no_java_in_wrapper

call "%EXISTING_JAVA_COMMAND%" -version >nul 2>&1

IF %ERRORLEVEL% NEQ 0 goto no_java_in_wrapper

FOR /f tokens^=2-3^ delims^=.-_^" %%j IN ('"%EXISTING_JAVA_COMMAND%" -fullversion 2^>^&1') do SET "jver=%%j%%k"

IF NOT %jver% == 18 (
    goto no_java_in_wrapper
) ELSE (
    SET "JAVA_COMMAND=%EXISTING_JAVA_COMMAND%"
    goto start_installer
)

:no_java_in_wrapper

rem #############################################################################################################
rem Check JAVA_HOME and the jre version in it.
rem #############################################################################################################
IF NOT DEFINED JAVA_HOME goto check_java_in_path
goto java_home_defined


:check_java_in_path
java >nul 2>&1
IF %ERRORLEVEL%==9009 (
    ECHO "Can't find a valid jre on this machine, please install jre 1.8.0_152 or later."
    pause
    goto :eof
)

FOR /f tokens^=2-3^ delims^=.-_^" %%j IN ('java -fullversion 2^>^&1') do SET "jver=%%j%%k"

IF NOT %jver% == 18 (
    ECHO "Error: Cannot find a valid Java installation on this computer. Please install JRE 1.8.0_152 or later 1.8 versions."
    pause
    goto :eof
) ELSE (
    ECHO Using java %jver% from PATH
    SET JAVA_COMMAND=java
    goto start_installer
)


:java_home_defined

rem Check if java home is set correctly
"%JAVA_HOME%\bin\java" -version >nul 2>&1

if %ERRORLEVEL% NEQ 0 (
    ECHO "Can't find java in JAVA_HOME/bin, looking for java in PATH."
    goto :check_java_in_path
)

FOR /f tokens^=2-3^ delims^=.-_^" %%j IN ('"%JAVA_HOME%\bin\java" -fullversion 2^>^&1') do SET "jver=%%j%%k"

rem Check the jre version in java home.
IF NOT %jver% == 18 (
    goto check_java_in_path
) ELSE (
    SET "JAVA_COMMAND=%JAVA_HOME%\bin\java"
    goto start_installer
)

:start_installer
echo Using java: %JAVA_COMMAND%
"%JAVA_COMMAND%" -classpath .;lib/* com.service_now.mid.installer.InstallerUI

