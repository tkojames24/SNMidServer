dim objShell

if wscript.arguments.count < 2 then
	Wscript.StdOut.WriteLine "missing arguments"
	WScript.Quit
end if

set objShell = wscript.createObject("wscript.shell") 

serviceName = wscript.arguments.item(1)
currentDirectory = left(WScript.ScriptFullName,(Len(WScript.ScriptFullName))-(len(WScript.ScriptName)))

if isServiceExists(serviceName) then
    Wscript.StdOut.WriteLine "service " & serviceName & " already installed, exiting..."
    WScript.Quit
end if

serviceExeFullPath = currentDirectory & wscript.arguments.item(0)

objShell.run "sc.exe create """ & serviceName & """ binPath= """ & serviceExeFullPath & """", 6, true
objShell.run "sc.exe start """ & serviceName & """", 6, true

Set objWMIService = GetObject("winmgmts:" & "{impersonationLevel=impersonate}!\\.\root\cimv2")
Set colServiceList = objWMIService.ExecQuery("Select * from Win32_Service where Name = '" & serviceName & "'")
if colServiceList.count = 0 then
	Wscript.StdOut.WriteLine "service installation failed"
else
	Wscript.StdOut.WriteLine "service successfully created"
end if

set objShell = Nothing

Function isServiceExists(serviceName)
    Set objWMIService = GetObject("winmgmts:" & "{impersonationLevel=impersonate}!\\.\root\cimv2")
    Set colServiceList = objWMIService.ExecQuery("Select * from Win32_Service where Name = '" & serviceName & "'")
	
	if colServiceList.count = 0 then
		isServiceExists = false
	else
        isServiceExists = true
	end if
end Function