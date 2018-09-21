set oHTTP = CreateObject("Msxml2.ServerXMLHTTP") 
if IsNull(oHTTP) or IsEmpty(oHTTP) Then
	set oHTTP = CreateObject("Msxml3.ServerXMLHTTP") 
end If
if IsNull(oHTTP) or IsEmpty(oHTTP) Then
	set oHTTP = CreateObject("Msxml4.ServerXMLHTTP") 
end If
oHTTP.open "GET", WScript.Arguments.Item(1) ,false 
oHTTP.setOption 2, 13056 
oHTTP.send 
set oStream = createobject("Adodb.Stream")
Set objFSO = CreateObject("Scripting.FileSystemObject") 
if objFSO.FileExists(WScript.Arguments.Item(0)) Then
	objFSO.DeleteFile(WScript.Arguments.Item(0))
End If
oStream.type = 1
oStream.open
oStream.write oHTTP.responseBody
oStream.savetofile WScript.Arguments.Item(0), 1
oStream.close
set oStream = nothing
Set oHTTP = Nothing 