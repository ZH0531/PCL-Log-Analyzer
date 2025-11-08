Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objShell = CreateObject("WScript.Shell")

' 获取报告文件夹路径
scriptPath = WScript.ScriptFullName
scriptFolder = objFSO.GetParentFolderName(scriptPath)
toolFolder = objFSO.GetParentFolderName(scriptFolder)
reportsFolder = objFSO.BuildPath(toolFolder, "Reports")

' 检查文件夹是否存在
If Not objFSO.FolderExists(reportsFolder) Then
    MsgBox "未找到报告文件夹", vbInformation, "提示"
    WScript.Quit
End If

' 统计HTML文件数量
Set folder = objFSO.GetFolder(reportsFolder)
fileCount = 0
For Each file In folder.Files
    If LCase(objFSO.GetExtensionName(file.Name)) = "html" Then
        fileCount = fileCount + 1
    End If
Next

' 如果没有文件
If fileCount = 0 Then
    MsgBox "没有可删除的报告", vbInformation, "提示"
    WScript.Quit
End If

' 确认删除
msg = "确定要删除 " & fileCount & " 个报告文件吗？" & vbCrLf & vbCrLf & "此操作无法撤销！"
result = MsgBox(msg, vbYesNo + vbExclamation, "确认删除")

If result = vbYes Then
    ' 删除所有HTML文件
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
    
    ' 显示结果
    If deleteCount = fileCount Then
        MsgBox "成功删除 " & deleteCount & " 个文件", vbInformation, "完成"
    Else
        MsgBox "已删除 " & deleteCount & " 个文件，失败 " & (fileCount - deleteCount) & " 个", vbExclamation, "部分成功"
    End If
End If
