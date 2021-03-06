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
Function GetCurrentFolderFullPath(fso,path)
    GetCurrentFolderFullPath = fso.GetParentFolderName(path)
End Function

'复制文件
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

Function cmdproc(cmdstr,prompt) 
	a=split(cmdstr,"&&")
	res=""
	for each row in a
	   	cmdline=row
	   
		if lcase(left(trim(cmdline),4))="echo" then
		 	cmdline=replace(cmdline,"echo","echo " & prompt) 
		else
			rd=""
			if instr(cmdline,"2>&1")>0 then
				rd=" >nul"
			end if
			cmdline="echo " & prompt & cmdline & rd & " && " & cmdline 
		end if
		
		if res="" then
			res=cmdline
	 	else
			res=res & " && " & cmdline
		end if
	next
	cmdproc=res
end function

sub exec( cmdstr, cmdprompt, cmdkeep)
	Set fso = CreateObject("Scripting.FileSystemObject")  
	set ws=createobject("wscript.shell")
	currDir= GetCurrentFolderFullPath(fso,Wscript.ScriptFullName) 
	cmdfile=currDir&"\cmd.bat"
	if fso.fileexists(cmdfile) then
		fso.deletefile cmdfile
	end if
	cmdstr=cmdproc(cmdstr,cmdprompt)
	Set fcmd = fso.opentextfile(cmdfile, 2, True)
	fcmd.writeline "@ECHO OFF"
	fcmd.write replace(cmdstr,"&&",vbcrlf) & vbcrlf
	if cmdkeep then
		fcmd.writeline "echo Execute completed! press any key to quit!"
		fcmd.writeline "pause >nul"
	end if
	fcmd.close
	ret=ws.run(cmdfile,1,true)
	
	fso.deletefile cmdfile
	
	set fcmd=Nothing
	set fso=Nothing
	set ws=Nothing
end sub

Function getcmd( cmd, prompt, logfile)
	Set fso = CreateObject("Scripting.FileSystemObject")  
	logline=" >> " & logfile & " 2>&1"
	cmd=cmd & " && " & cmd & logline
	exec cmd,prompt,0
	
	if fso.fileexists(logfile) then
		Set f = fso.OpenTextFile(logfile, 1)
		strRet = f.ReadAll
		f.Close
		fso.deletefile logfile
		Set f=Nothing
	end if
	
	set fso=Nothing
	getcmd=strRet
end function

Function Collection()
		set Collection = CreateObject("Scripting.Dictionary")
End Function

Function QuickSort(Arr)
    Dim i, j
    Dim bound, t
    bound = UBound(Arr)

    For i = 0 To bound - 1
        For j = i + 1 To bound
            If Arr(i) > Arr(j) Then
                t = Arr(i)
                Arr(i) = Arr(j)
                Arr(j) = t
            End If
        Next
    Next
    QuickSort = Arr
End Function

Function getRandom(minb,maxb)
	Randomize
	getRandom=Int((maxB-minB+1)*Rnd+minB)
end function

sub setFileAttr(fso,fpath,attr)
	Set f = fso.GetFile(fpath)
	If not (f.attributes and attr) Then
	   f.attributes = f.attributes + attr
	End If
end sub

sub clearFileAttr(fso,fpath,attr)
	Set f = fso.GetFile(fpath)
	If (f.attributes and attr) Then
	   f.attributes = f.attributes - attr
	End If
end sub