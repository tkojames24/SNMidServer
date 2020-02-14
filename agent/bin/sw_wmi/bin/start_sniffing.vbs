dim objShell, username, password, serviceExeFullPath, bits, objFSO, logFile

set objShell = wscript.createObject("wscript.shell") 
Dim env : Set env = objShell.Environment("PROCESS")
env("SEE_MASK_NOZONECHECKS") = 1

if wscript.arguments.count < 1 then
	Log "missing arguments"
	WScript.Quit
end if

pid = wscript.arguments.item(0)
serviceName = "InjectorService" & pid
currentDirectory = left(WScript.ScriptFullName,(Len(WScript.ScriptFullName))-(len(WScript.ScriptName)))

set objFSO = CreateObject("Scripting.FileSystemObject")
if IsObject(objFSO) then
	set logFile = objFSO.OpenTextFile(currentDirectory & "sss-" & pid & ".log", 2, true)
end if

if isServiceExists(serviceName) then
    Log "service " & serviceName & " already installed, exiting..."
    WScript.Quit
end if

serviceExeFullPath = currentDirectory & "InjectorService.exe " & pid & " t_hook.dll 3"
bits = wscript.arguments.item(1)

if wscript.arguments.count > 2 then
	username = wscript.arguments.item(2)
end if
if wscript.arguments.count > 3 then
	password = wscript.arguments.item(3)
end if

if username <> "" and InStr(username, "\") = 0 then
	hostname = getHostname()
    if hostname <> "" then
        username = hostname & "\" & username
    end if
end if

VerifyLogonAsAServiceRights

if not username = "" and not password = "" then
	Log "sc.exe create " & serviceName & " binPath= """ & serviceExeFullPath & """" & " obj= " & username & " password= ******"
	objShell.run "sc.exe create " & serviceName & " binPath= """ & serviceExeFullPath & """" & " obj= " & username & " password= " & password, 6, true
elseif not username = "" then
    Log "sc.exe create " & serviceName & " binPath= """ & serviceExeFullPath & """" & " obj= " & username
	objShell.run "sc.exe create " & serviceName & " binPath= """ & serviceExeFullPath & """" & " obj= " & username, 6, true
else
	Log "sc.exe create " & serviceName & " binPath= """ & serviceExeFullPath & """"
	objShell.run "sc.exe create " & serviceName & " binPath= """ & serviceExeFullPath & """", 6, true
end if

Log "sc.exe start " & serviceName
objShell.run "sc.exe start " & serviceName, 6, true

Set objWMIService = GetObject("winmgmts:" & "{impersonationLevel=impersonate}!\\.\root\cimv2")

' domain check
Set colItems = objWMIService.ExecQuery( "Select * from Win32_ComputerSystem" )
For Each objItem in colItems
    If Not objItem.PartOfDomain Then
		Log "Computer is not part of a domain, skipping sniffing..."
		WScript.Quit
    End If
	Exit For
Next

run = True
while run
	Set colServiceList = objWMIService.ExecQuery("Select * from Win32_Service where Name = '" & serviceName & "'")

	if colServiceList.count = 0 then
		Log "service installation failed" ' do not change the message, java expects it
		run = false 'installation failed
	end if
	
	for each s in colServiceList
		'Wscript.StdOut.WriteLine s.name & "-" & s.state
		if s.state = "Stopped" then 
			run = false
		end if
	next
	
	wscript.sleep 1000
wend

' to be sure
Log "sc.exe stop " & serviceName
objShell.run "sc.exe stop " & serviceName, 6, true
Log "sc.exe delete " & serviceName
objShell.run "sc.exe delete " & serviceName, 6, true

Log "finished to remove service " & serviceName

if IsObject(logFile) then
	logFile.Close
	set logFile = Nothing
end if

set objFSO = Nothing
set objShell = Nothing

Function VerifyLogonAsAServiceRights()
    errorCode = objShell.run(bits & "\CheckUserRights.exe " & username, 6, true)
    if errorCode <> 0 then
        errorCode = objShell.run(bits & "\ntrights.exe +r SeServiceLogonRight -u " & username, 6, true)
        if errorCode <> 0 then
            Log "ntrights exited with " & errorCode
        end if
    end if
End Function

Function isServiceExists(serviceName)
    Set objWMIService = GetObject("winmgmts:" & "{impersonationLevel=impersonate}!\\.\root\cimv2")
    Set colServiceList = objWMIService.ExecQuery("Select * from Win32_Service where Name = '" & serviceName & "'")
	
    if colServiceList.count = 0 then
		isServiceExists = false
		exit function
    end if
	
	for each s in colServiceList
		if s.state = "Stopped" then 
			Log "uninstalling old service"
			Log "sc.exe stop " & serviceName
			objShell.run "sc.exe stop " & serviceName, 6, true
			Log "sc.exe delete " & serviceName
			objShell.run "sc.exe delete " & serviceName, 6, true
			Log "finished to remove old service " & serviceName
		end if
	next
	
	Set colServiceList = objWMIService.ExecQuery("Select * from Win32_Service where Name = '" & serviceName & "'")
	if colServiceList.count = 0 then
		isServiceExists = false
	else
        isServiceExists = true
	end if
end Function

Function getHostname()
    on error resume next

    strHostName = objShell.RegRead("HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Hostname")
    if strHostName <> "" then
        getHostname = strHostName
        exit function
    end if

    Set objNTInfo = CreateObject("WinNTSystemInfo")
    if IsObject(objNTInfo) then
        if objNTInfo.ComputerName <> "" then
	        getHostname = objNTInfo.ComputerName
            exit function
        end if
    end if

    Set objIP = CreateObject("SScripting.IPNetwork")
    if IsObject(objIP) then
        if objIP.Hostname <> "" then
            getHostname = objIP.Hostname
            exit function
        end if
    end if

    getHostname = ""
end function

Sub Log(line)
	on error resume next
	
	if IsObject(objFSO) And IsObject(logFile) then
		logFile.WriteLine line
	end if
	
	Wscript.StdOut.WriteLine line
End Sub