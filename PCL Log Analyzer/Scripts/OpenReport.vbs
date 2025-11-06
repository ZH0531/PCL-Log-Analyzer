Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objArgs = WScript.Arguments

If objArgs.Count > 0 Then
    filePath = objArgs(0)
    browserPath = ""
    
    On Error Resume Next
    
    ' 从注册表读取系统默认浏览器
    ' 方法1: 读取 HTTP 协议关联的浏览器
    progId = objShell.RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice\ProgId")
    If progId <> "" Then
        commandKey = "HKEY_CLASSES_ROOT\" & progId & "\shell\open\command\"
        browserCommand = objShell.RegRead(commandKey)
        
        ' 提取可执行文件路径（去掉参数）
        If InStr(browserCommand, Chr(34)) > 0 Then
            ' 路径被引号包裹
            browserPath = Mid(browserCommand, 2, InStr(2, browserCommand, Chr(34)) - 2)
        Else
            ' 没有引号，取第一个空格前的部分
            spacePos = InStr(browserCommand, " ")
            If spacePos > 0 Then
                browserPath = Left(browserCommand, spacePos - 1)
            Else
                browserPath = browserCommand
            End If
        End If
    End If
    
    On Error GoTo 0
    
    ' 使用系统默认浏览器打开文件
    If browserPath <> "" And objFSO.FileExists(browserPath) Then
        objShell.Run Chr(34) & browserPath & Chr(34) & " " & Chr(34) & filePath & Chr(34), 0, False
    Else
        ' 兜底：使用系统默认方式打开
        objShell.Run Chr(34) & filePath & Chr(34), 0, False
    End If
End If

