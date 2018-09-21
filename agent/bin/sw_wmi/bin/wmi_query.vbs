
dim objShell
set objShell = wscript.createObject("wscript.shell")

if wscript.arguments.count < 2 then
	Log "ERROR: missing arguments"
	WScript.Quit
end if

namespace = wscript.arguments.item(0)
query = wscript.arguments.item(1)

Set objWMIService = GetObject("winmgmts:" & "{impersonationLevel=impersonate}!\\." & namespace)
Set objSet = objWMIService.ExecQuery(query)

Wscript.StdOut.WriteLine "NeebulaStartResult"

for each obj in objSet
	Wscript.StdOut.WriteLine "NeebulaStartRow"
	Wscript.Echo "Path :" & obj.Path_
    for each p in obj.Properties_
	    if p.IsArray then
            if Not IsNull(p.Value) then
				if (p.Name = "ServerBindings") then
					serverBindings(p)
				else
					if (p.Name = "SecureBindings") then
						secureBindings(p)
					else
						Wscript.StdOut.WriteLine p.Name & " : " & "NeebulaArrayDelimiter" & Join(p.Value, "NeebulaArrayDelimiter")
					end if
				end if
            else
                Wscript.StdOut.WriteLine p.Name & " : "
            end if
        else
		    if (p.CIMType = 103) Then
			    Wscript.StdOut.WriteLine p.Name & " : " & Chr(CInt(p.Value))
			else
   			    Wscript.StdOut.WriteLine p.Name & " : " & p.Value
            End If
        end if
    next
next
Wscript.StdOut.WriteLine "NeebulaEndResult"


sub serverBindings(p)
    Wscript.StdOut.Write p.Name & " : "
    for i = 0 to UBound(p.Value)
	    Wscript.StdOut.Write "NeebulaArrayDelimiter"
        Wscript.StdOut.Write "NeebulaStartObject"
		Wscript.StdOut.Write "NeebulaEndFieldValueNeebulaStartFieldNameHostnameNeebulaEndFieldNameNeebulaStartFieldValue" & p(i).Hostname & "NeebulaEndFieldValueNeebulaStartFieldNameIPNeebulaEndFieldNameNeebulaStartFieldValue" & p(i).IP & "NeebulaEndFieldValueNeebulaStartFieldNamePortNeebulaEndFieldNameNeebulaStartFieldValue" & p(i).Port & "NeebulaEndFieldValue"
		Wscript.StdOut.Write "NeebulaEndObject" 
	next
	Wscript.Stdout.Write vbCrLf
end sub

sub secureBindings(p)
    Wscript.StdOut.Write p.Name & " : "
    for i = 0 to UBound(p.Value)
	    Wscript.StdOut.Write "NeebulaArrayDelimiter"
        Wscript.StdOut.Write "NeebulaStartObject"
		Wscript.StdOut.Write "NeebulaStartFieldNameIPNeebulaEndFieldNameNeebulaStartFieldValue" & p(i).IP & "NeebulaEndFieldValueNeebulaStartFieldNamePortNeebulaEndFieldNameNeebulaStartFieldValue" & p(i).Port & "NeebulaEndFieldValue"
		Wscript.StdOut.Write "NeebulaEndObject" 
	next
	Wscript.Stdout.Write vbCrLf
end sub
