'创建目录
Sub CreateDir(Folder)
  Dim RegEx, arrFolder, thisFolder
  'MsgBox "hist:" & Folder
  '使用正则表达式搜索出每级目录 便于依次创建
  Set RegEx = New RegExp
  RegEx.Pattern = "[^\\]+\\" '搜索所有的非\字符和\ 如d:\a\网络\cc 则结果为 d:\  a\  网络\  cc
  RegEx.IgnoreCase = True
  RegEx.Global = True
  Set arrFolder = RegEx.Execute(Folder)
  
  Set RegEx = Nothing
  
  Set fso = CreateObject("Scripting.FileSystemObject")
  
  For Each SubFolder In arrFolder
  
      thisFolder = thisFolder & SubFolder '一层一层的推进
      'MsgBox thisFolder
      If Not fso.FolderExists(thisFolder) Then
         fso.CreateFolder(thisFolder) '如果该层不存在则创建
      End If
      
  Next
  Set fso = Nothing
End Sub

'复制目录
sub CopyDir(fso,srcFolder,destFolder)
	If Not fso.FolderExists(destFolder) Then
	    CreateDir destFolder
	End If
	
	fso.CopyFolder srcFolder,destFolder
End sub

' 取得文件扩展名和基本名.
Function GetFileExtAndBaseName(ByVal sfilename, ByRef sbasename)
    n = InStrRev(sfilename, ".")
    If n>1 Then
        GetFileExtAndBaseName = Mid(sfilename, n+1)
        sbasename = Left(sfilename, n-1)
    Else
        GetFileExtAndBaseName = ""
        sbasename = sfilename
    End If
End Function

'得到脚本文件所在的当前目录
Function GetCurrentFolderFullPath(fso)
    GetCurrentFolderFullPath = fso.GetParentFolderName(WScript.ScriptFullName)
End Function

sub cpfile(fso,src,dest)
	if fso.FileExists(src) then
		destDir=left(dest,instrrev(dest,"\"))
		if not fso.FolderExists(destDir) then
			CreateDir(destDir)
		end if
		
		fso.CopyFile src,dest
	end if
end sub

Function GetMAC()
    GetMAC = ""
    Dim mc,mo
    Set mc = GetObject("Winmgmts:").InstancesOf("Win32_NetworkAdapterConfiguration")
    For Each mo In mc
        If mo.IPEnabled = True Then
            GetMAC = mo.MacAddress
            Exit For
        End If
    Next
    Set mc = nothing
End Function