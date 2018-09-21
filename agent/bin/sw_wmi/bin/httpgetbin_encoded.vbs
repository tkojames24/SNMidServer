Set objFSO = CreateObject("Scripting.FileSystemObject") 
set oHTTP = CreateObject("Msxml2.ServerXMLHTTP") 
oHTTP.open "GET", WScript.Arguments.Item(1) ,false 
oHTTP.setOption 2, 13056 
oHTTP.send 
Set objFile = objFSO.OpenTextFile(WScript.Arguments.Item(0), 2, True) 
For x = 1 To Len(oHTTP.responseText) Step 2 
objFile.Write Chr(Clng("&H" & Mid(oHTTP.responseText,x,2))) 
Next 
objFile.Close 
