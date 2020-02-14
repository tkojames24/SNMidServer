dim objShell
set objShell = wscript.createObject("wscript.shell")

if wscript.arguments.count < 2 then
	Log "ERROR: missing arguments"
	WScript.Quit
end if

strNameSpace = wscript.arguments.item(0)
strClass = wscript.arguments.item(1)

 
Set objClass = GetObject("winmgmts:" & "{impersonationLevel=impersonate}!\\." & strNameSpace & ":" & strClass)
Wscript.StdOut.WriteLine "NeebulaStartResult"
 
For Each objClassProperty In objClass.Properties_
    WScript.StdOut.WriteLine objClassProperty.Name
Next

