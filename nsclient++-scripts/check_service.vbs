'Set args = WScript.Arguments
'If args.Count <> 1 Then
'    WScript.StdErr.WriteLine "usage: scriptname arg1"
'    WScript.Quit
'End If



strComputer = "."
Set objWMIService = GetObject( _
    "winmgmts:\\" & strComputer & "\root\CIMV2")
Set colItems = objWMIService.ExecQuery( _
    "SELECT * FROM Win32_Service",,48)
For Each objItem in colItems
'    WScript.StdErr.WriteLine WScript.Arguments(0)
    If objItem.Name = WScript.Arguments(1)  Then
        Wscript.Echo "Service Name: " & objItem.Name & " "  & "State: " & objItem.State
    End If
Next

