dim objShell, objExecObject, command, username, password, serviceExeFullPath, objFSO, objFile
Set objFSO = CreateObject("Scripting.FileSystemObject")

set objShell = wscript.createObject("wscript.shell") 

if wscript.arguments.count < 3 then
	Wscript.StdOut.WriteLine "missing arguments"
	WScript.Quit
end if

salt = wscript.arguments.item(0)
params = getParams(salt)
serviceName = "ServiceNowPsExec" & salt
currentDirectory = left(WScript.ScriptFullName,(Len(WScript.ScriptFullName))-(len(WScript.ScriptName)))

if LCase(wscript.arguments.item(1)) = "powershell" then
    Set objFile = objFSO.CreateTextFile(currentDirectory & salt & "_input.txt")
    objFile.WriteLine(params)
    objFile.Close
    set objFile = Nothing

    command = "\""" & currentDirectory & "powershell_executor.exe\"" \""" & currentDirectory & salt & "_input.txt\"" \""" & currentDirectory & "psexec" & salt & ".txt\"""
else
	command = "\""" & wscript.arguments.item(1) & "\"" " & params & " \""" & currentDirectory & "psexec" & salt & ".txt\"""
end if

serviceExeFullPath = wscript.arguments.item(2)

if wscript.arguments.count > 3 then
	username = wscript.arguments.item(3)
end if
if wscript.arguments.count > 4 then
	password = wscript.arguments.item(4)
end if

VerifyLogonAsAServiceRights

if not username = "" and not password = "" then
	Wscript.StdOut.WriteLine "sc.exe create " & serviceName & " binPath= """ & serviceExeFullPath & " " & command & """" & " obj= " & username & " password= ******"
	objShell.run "sc.exe create " & serviceName & " binPath= """ & serviceExeFullPath & " " & command & """" & " obj= " & username & " password= " & password, 6, true
elseif not username = "" then
	objShell.run "sc.exe create " & serviceName & " binPath= """ & serviceExeFullPath & " " & command & """" & " obj= " & username, 6, true
else
	Wscript.StdOut.WriteLine "sc.exe create " & serviceName & " binPath= """ & serviceExeFullPath & " " & command & """"
	objShell.run "sc.exe create " & serviceName & " binPath= """ & serviceExeFullPath & " " & command & """", 6, true
end if

Wscript.StdOut.WriteLine "sc.exe start " & serviceName
objShell.run "sc.exe start " & serviceName, 6, true

Set objWMIService = GetObject("winmgmts:" & "{impersonationLevel=impersonate}!\\.\root\cimv2")

run = True
while run
	Set colServiceList = objWMIService.ExecQuery("Select * from Win32_Service where Name = '" & serviceName & "'")

	if colServiceList.count = 0 then
		Wscript.StdOut.WriteLine "psexec service installation failed" ' do not change the message, java expects it
		run = false 'installation failed
	end if
	
	for each s in colServiceList
		Wscript.StdOut.WriteLine s.name & "-" & s.state
		if s.state = "Stopped" then 
			run = false
		end if
	next
	
	wscript.sleep 1000
wend

' to be sure
Wscript.StdOut.WriteLine "sc.exe stop " & serviceName
objShell.run "sc.exe stop " & serviceName, 6, true
Wscript.StdOut.WriteLine "sc.exe delete " & serviceName
objShell.run "sc.exe delete " & serviceName, 6, true

Wscript.StdOut.WriteLine "finished to remove service " & serviceName

if not objFSO is Nothing then
    if objFSO.FileExists(currentDirectory & salt & "_input.txt") then
        objFSO.DeleteFile(currentDirectory & salt & "_input.txt")
    end if
    set objFSO = Nothing
end if

set objShell = Nothing


Function getParams(salt)
    if not objFSO.FileExists("params" & salt & ".txt") then
        getParams = ""
    else
        Set objFile = objFSO.OpenTextFile("params" & salt & ".txt", 1)
        strText = objFile.ReadAll
		objFile.Close
        set objFile = Nothing

        getParams = Replace(strText, """", "\""")
    end if
end Function

Function VerifyLogonAsAServiceRights()
    errorCode = objShell.run("CheckUserRights.exe " & username, 6, true)
    if errorCode <> 0 then
        errorCode = objShell.run("ntrights.exe +r SeServiceLogonRight -u " & username, 6, true)
        if errorCode <> 0 then
            Wscript.StdOut.WriteLine "ntrights exited with " & errorCode
        end if
    end if
End Function