If Wscript.Arguments.Length < 3 Then
	Wscript.Echo "Missing parameters"
	Wscript.Quit
End If

sFolder = Wscript.Arguments.Item(0)
If sFolder = "" Then
  Wscript.Echo "No Folder parameter was passed"
  Wscript.Quit
End If

outFile = Wscript.Arguments.Item(1)
queuePattern = Wscript.Arguments.Item(2)

Set cbRe = new regexp
cbRe.Pattern = ".*<%@\s*Page\s+.*CodeBehind=""~?/?([\w\.\\/]*)"".*"
cbRe.IgnoreCase = true
cbRe.Global = True

Set cfRE = new regexp
cfRE.Pattern = ".*<%@\s*Page\s+.*CodeFile=""([\w\.\\/]*)"".*"
cfRE.IgnoreCase = true
cfRE.Global = True

Set refRE = new regexp
refRE.Pattern = ".*<%@\s*Reference\s+.*Page=""([\w\.\\/]*)"".*"
refRE.IgnoreCase = true
refRE.Global = True

Set srcRE = new regexp
srcRE.Pattern = ".*<%@\s*Page\s+.*Src=""~?/?([\w\.\\/]*)"".*"
srcRE.IgnoreCase = true
srcRE.Global = True

Set qRE = new regexp
'qRE.Pattern = ".*(formatname:(dl|direct|public|private|multicast|machine)=[\w-\.\\/$:;]+).*"
qRE.Pattern = queuePattern
qRE.IgnoreCase = true
qRE.Global = True

Set fileNames = CreateObject("Scripting.Dictionary")
Set queues = CreateObject("Scripting.Dictionary")

Const ForReading = 1
Const ForAppending = 8
Set fso = CreateObject("Scripting.FileSystemObject")
Set folder = fso.GetFolder(sFolder)
Set files = folder.Files

For each folderIdx In files
    CheckFile folderIdx.Path
Next

for each file in fileNames.Keys()
    'Wscript.StdOut.WriteLine file
	HandleFile file
next

Set objOutFile = fso.OpenTextFile(outFile, ForAppending, True)
for each s in queues.Keys()
    Wscript.StdOut.WriteLine s
    objOutFile.WriteLine s
next
objOutFile.Close

Function CheckFile(path)
    if Len(path) = 0 Then 
        Exit Function
    End If

    'Wscript.StdOut.WriteLine "checking file " & path

    If (Len(path) > 5 And Right(path, 5) = ".aspx") Or (Len(path) > 3 And Right(path, 3) = ".cs") Or (Len(path) > 5 And Right(path, 5) = ".html") Or (Len(path) > 4 And Right(path, 4) = ".htm") Then
	    if fileNames.Exists(path) then 
            Exit Function
        end if

        fileNames.Add path, path
        for each include in GetIncludes(path)
            CheckFile include
        next
    End If
End Function

Function GetIncludes(path)
    Dim includes()

    Set objFile = fso.OpenTextFile(path, ForReading)
	strText = objFile.ReadAll
	objFile.Close

    parentFolderName = fso.GetParentFolderName(path)

    If InStr(strText, vbCrLf) > 0 Then
		arrFileLines = Split(strText, vbCrLf)
	Else
		arrFileLines = Split(strText, vbCr)
	End If

    count = 0
    for each line in arrFileLines
        if cbRe.Test(line) then
            'Wscript.StdOut.WriteLine line
            Set Matches = cbRe.Execute(line)
			For Each Match in Matches
				s = Match.SubMatches(0)
                'Wscript.StdOut.WriteLine s

                ReDim Preserve includes(count + 1)
                includes(count) = parentFolderName & "\" & s
                count = count + 1
			Next
        end if
        if cfRe.Test(line) then
            'Wscript.StdOut.WriteLine line
            Set Matches = cfRe.Execute(line)
			For Each Match in Matches
				s = Match.SubMatches(0)
                'Wscript.StdOut.WriteLine s

                ReDim Preserve includes(count + 1)
                includes(count) = parentFolderName & "\" & s
                count = count + 1
			Next
        end if
        if refRe.Test(line) then
            'Wscript.StdOut.WriteLine line
            Set Matches = refRe.Execute(line)
			For Each Match in Matches
				s = Match.SubMatches(0)
                'Wscript.StdOut.WriteLine s

                ReDim Preserve includes(count + 1)
                includes(count) = parentFolderName & "\" & s
                count = count + 1
			Next
        end if
        if srcRe.Test(line) then
            'Wscript.StdOut.WriteLine line
            Set Matches = srcRe.Execute(line)
			For Each Match in Matches
				s = Match.SubMatches(0)
                'Wscript.StdOut.WriteLine s

                ReDim Preserve includes(count + 1)
                includes(count) = parentFolderName & "\" & s
                count = count + 1
			Next
        end if
    next

    GetIncludes = includes
End Function

Function HandleFile(file)
    'Wscript.StdOut.WriteLine "handling file " & file

	Set objFile = fso.OpenTextFile(file, ForReading)		
	strText = objFile.ReadAll
	objFile.Close

    'Wscript.StdOut.WriteLine strText
		
	If InStr(strText, vbCrLf) > 0 Then
		arrFileLines = Split(strText, vbCrLf)
	Else
		arrFileLines = Split(strText, vbCr)
	End If

	For Each strLine in arrFileLines
        'Wscript.StdOut.WriteLine strLine
		If qRE.Test(strLine) Then
			Set Matches = qRE.Execute(strLine)
			For Each Match in Matches
				s = Match.SubMatches(0)
                if not queues.Exists(s) then queues.Add s, s
			Next
		End If
	Next
End Function