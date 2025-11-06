Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objShell = CreateObject("WScript.Shell")

' Get Reports folder path
scriptPath = WScript.ScriptFullName
scriptFolder = objFSO.GetParentFolderName(scriptPath)
toolFolder = objFSO.GetParentFolderName(scriptFolder)
reportsFolder = objFSO.BuildPath(toolFolder, "Reports")

' Check if folder exists
If Not objFSO.FolderExists(reportsFolder) Then
    MsgBox "Reports folder not found", vbInformation, "Info"
    WScript.Quit
End If

' Count HTML files
Set folder = objFSO.GetFolder(reportsFolder)
fileCount = 0
For Each file In folder.Files
    If LCase(objFSO.GetExtensionName(file.Name)) = "html" Then
        fileCount = fileCount + 1
    End If
Next

' If no files
If fileCount = 0 Then
    MsgBox "No reports to delete", vbInformation, "Info"
    WScript.Quit
End If

' Confirm deletion
msg = "Delete " & fileCount & " report file(s)?" & vbCrLf & vbCrLf & "This cannot be undone!"
result = MsgBox(msg, vbYesNo + vbExclamation, "Confirm Delete")

If result = vbYes Then
    ' Delete all HTML files
    On Error Resume Next
    deleteCount = 0
    For Each file In folder.Files
        If LCase(objFSO.GetExtensionName(file.Name)) = "html" Then
            file.Delete True
            If Err.Number = 0 Then
                deleteCount = deleteCount + 1
            End If
        End If
    Next
    On Error GoTo 0
    
    ' Show result
    If deleteCount = fileCount Then
        MsgBox "Successfully deleted " & deleteCount & " file(s)", vbInformation, "Complete"
    Else
        MsgBox "Deleted " & deleteCount & " file(s), failed " & (fileCount - deleteCount), vbExclamation, "Partial Success"
    End If
End If
