Dim srcPath
Dim destPath
Dim histPath
Dim destHist
Dim currDate

' Include������ͨ��FSO�����ȡ�ⲿ�����ļ�����
' ͨ��ExecuteGlobal����
Sub include(file)
    Dim fso, f, strcon
    Set fso = CreateObject("Scripting.FileSystemObject")
    Set f = fso.OpenTextFile(file, 1)
    strcon = f.ReadAll
    f.Close
    ExecuteGlobal strcon
    Set fso=Nothing
    Set f=Nothing
End Sub

sub fileArch(fso,filename,file,path)
    dpath=""
	if instr(filename,"CREATE_PACKAGE_BODY_")>0 or  instr(filename,"CREATE_PACKAGE_SPEC_")>0 then
		dpath=path&"\package\"
	elseif  instr(filename,"CREATE_VIEW_")>0  then
		dpath=path&"\view\"
	elseif instr(filename,"CREATE_TABLE_")>0  then
		dpath=path&"\table\"
	elseif instr(filename,"CREATE_SYNONYM_")>0  then
		dpath=path&"\synonym\"
	elseif instr(filename,"CREATE_SEQUENCE_")>0  then
		dpath=path&"\sequence\"
	elseif instr(filename,"CREATE_MATERIALIZED_VIEW_")>0  then
		dpath=path&"\mv\"
	elseif instr(filename,"CREATE_TRIGGER_")>0  then
		dpath=path&"\trigger\"
	elseif instr(filename,"CREATE_PROCEDURE_")>0  then
		dpath=path&"\procedure\"
	elseif instr(filename,"CREATE_FUNCTION_")>0  then
		dpath=path&"\function\"
	end if
    
    if dpath<>"" then
    	cpfile fso,file,dpath
    end if
end sub

' ������Ŀ¼����Ŀ¼.
'
' Result: Ŀ¼���ļ�������.
' fileOut: ����ļ�����������������.
' fso: FileSystemObject����.
' sPath: Ŀ¼.
Function dirscan( fso, sPath,archPath)
    rt = 0
    Set currentFolder = Nothing
    'MsgBox sPath
    
    On Error Resume Next
    Set currentFolder = fso.GetFolder(sPath)
    On Error Goto 0
    
    If Not (currentFolder is Nothing) Then
        ' Folders
        For Each subFolder in currentFolder.SubFolders
            sfull = subFolder.Path     ' ȫ�޶���.
            's = "D" & vbTab & sfull & vbTab & subFolder.Name & vbTab  & "" & vbCrLf
            'fileOut.write s
            rt = rt + dirscan(fso, subFolder.Path,archPath)
          	
        Next
        
        ' Files
        For Each f in currentFolder.Files
            sbase = ""
            sext = GetFileExtAndBaseName(f.Name, sbase)    ' ��չ��.
            sfull = f.Path    ' ȫ�޶���.
            rt = rt + 1
            if sext ="sql" or sext="pls" or sext="plb" then
            	fileArch fso,f.Name,sfull,archPath
          	end if 
            
        Next
    End If
    
    dirscan = rt
End Function

' ����
Sub dotest
		Set fso = CreateObject("Scripting.FileSystemObject")  
		Set f = fso.OpenTextFile("download_conn.cfg", 1)
		strJson = f.ReadAll
		f.Close
		Set f=Nothing
	
		'��ȡ��������
		Set html = CreateObject("htmlfile")
    	Set window = html.parentWindow
   		window.execScript "var json = "&strJson&"", "JScript"
		Set cfg = window.json
    	rhost=cfg.app.host
    	ruser=cfg.app.user
    	rpw=cfg.app.pwd
    	dbsid=cfg.db.sid
    	dbuser=cfg.db.user
    	dbpw=cfg.db.pwd
    	cuxpw=cfg.db.cuxpwd
    	nlslang=cfg.db.nls_lang
    	list=cfg.listfile
    	dbtype=cfg.dbtype
    	
    
    	
		'�����ļ������
		include "..\lib\lib.vbs"

    	currDir= GetCurrentFolderFullPath(fso) 	
    	currPDir=fso.GetParentFolderName(currDir)

    	currDate=CStr(Year(Now()))&Right("0"&Month(Now()),2)&Right("0"&Day(Now()),2)
    	
    	dim maxB,minB
		maxB=10000
		minb=1
		'Randomize
		rd=Int((maxB-minB+1)*Rnd+minB)
    	
    	'Msgbox "begin:"&currDate&","&Date&" "&Time
    	rtdir="download_"&currDate&"_"&rd
    	
    	'ɾ�������ļ�Ŀ¼	
    	condir=currDir & "\"&rtDir
	 	if fso.folderexists(condir) then  	
			fso.deletefolder(condir)
		end if
		
		'ɾ������Ŀ¼
		condir=currDir & "\code"
	 	if fso.folderexists(condir) then  	
			fso.deletefolder(condir)
		end if
		
		dbcnt =0
		appcnt=0
    	dblist=""
    	applist=""
		if dbtype="script" then
    		
			dblist="listdb.cfg"
			applist="listapp.cfg"
			Set flist = fso.OpenTextFile(currdir&"\"&list, 1)
    		Set fdblist = fso.opentextfile(currdir&"\"&dblist, 2, True)    ' ������ļ�. ForWriting, TristateTrue.
    		Set fapplist = fso.opentextfile(currdir&"\"&applist, 2, True)    ' ������ļ�. ForWriting, TristateTrue.
    		Do Until flist.AtEndOfStream
				objline=flist.readline
				oa=split(objline,"|")
				otype=oa(0)
				if otype="TABLE" or otype="VIEW" or otype="SYNONYM" _
					or otype="SEQUENCE" or otype="PACKAGE" or otype="PACKAGE BODY"_
					or otype="PROCEDURE" or otype="FUNCTION"  or otype="TRIGGER" or otype="MATERIALIZED_VIEW" then
					fdblist.writeline objline
					dbcnt=dbcnt+1
			  	elseif otype<>"" then
			  		appcnt=appcnt+1
			    	fapplist.writeline objline
				end if
			LOOP
		
    	    if dbcnt=0 then
				dblist=""
			end if
			if appcnt=0 then
				applist=""
			end if
			flist.close
			fdblist.close
			fapplist.close
		else
			applist=listfile
    	end if
    	
		cmds="%comspec% /k"
		scpm=currPDir&"\lib\pscp.exe -q -r  -pw "&rpw 'ssh�ļ��ϴ�����������
		
    	sshm=currPDir&"\lib\plink.exe -ssh  -pw "&rpw&" "&ruser&"@"&rhost&" """ 'ssh����
    	
		set ws=createobject("wscript.shell")
		'host = WScript.FullName
		'If LCase( right(host, len(host)-InStrRev(host,"\")) ) = "wscript.exe" Then
		 '  ws.run "cscript """ & WScript.ScriptFullName & chr(34), 0
		  ' WScript.Quit
		'End If
		
    	'spt=sshm&"echo $0"""
		'set oexec=ws.exec(spt)
    	'rshtype=replace(oexec.StdOut.Readall,chr(10),"")
    	'Msgbox "x"&rshtype&"x"
    	'if rshtype ="ksh" then
    	'	rprof="~/.profile;"
      	'else
      	'	rprof="~/.bash_profile;"
    	'end if
    		
    	listfile=""
    	fmfile="perl -pi -e 's/^\xEF\xBB\xBF|\xFF\xFE//' [file]; perl -pi -e 's/\r\n/\n/' [file];" '�б��ļ���ʽ����ȥ��UTF-8��BOMͷ��windows���з�\r\nת��Ϊunix���з�\n\

		renv="NLS_LANG='"&nlslang&"';export NLS_LANG;. ./setenv.sh;" '��������
    	
    	sshpre="cd $HOME/"&rtdir&"; chmod +x ./*; "&renv&"echo ""NLS_LANG=$NLS_LANG"";"
    	
    	sshupf=" echo ==)begin get ddl process: && echo ==)uploading script file to server...... "&_
    			  " && "&sshm&" rm -rf ~/"&rtdir&"; mkdir ~/"&rtdir&";"""&_ 
    			  " && "&scpm&" "&currPDir&"\lib\common\ "&ruser&"@"&rhost&":"&rtdir&_
    			  " && "&scpm&" "&currPDir&"\lib\download\ "&ruser&"@"&rhost&":"&rtdir 'ɾ������Ŀ¼����������ʱĿ¼,�ϴ�ִ�нű�
    			  	
    	if dblist<>"" then
    		listfile=dblist
    		sshupf=sshupf&" && "&scpm&" "&currDir&"\"&listfile&" "&ruser&"@"&rhost&":"&rtdir  '�ϴ�objlist
	    	sshdbd=" && echo ==)begin execute db download:  "&_
	    					" && "&sshm&sshpre&replace(fmfile,"[file]",listfile)&"slc_getddl_all.sh "&dbsid&" "&dbuser&" "&dbpw&" -f "&dblist&";"""&_ 
	    					" && echo ==)execute db download completed  ! "     	'����db�ļ�
	    end if	    	
	    	
    	if applist<>"" then
    		listfile=applist
    		sshupf=sshupf&" && "&scpm&" "&currDir&"\"&listfile&" "&ruser&"@"&rhost&":"&rtdir  '�ϴ�objlist
	    	sshappd=" && echo ==)begin execute app download: "&_
	    					" && "&sshm&sshpre&replace(fmfile,"[file]",listfile)&"perl download.pl placepath=. cfgfile=./download.cfg listfile=./"&applist&_
    						" appsusr="&dbuser&" appspwd="&dbpw&" logfile=./downapp.log dbschemapwd="&cuxpw&";"""&_ 
    						" && echo ==)execute app download completed "'����app�ļ�
    	end if
    		
    	sshupf=sshupf&" && echo ==)uploaded scripts successful ! " 
    	
        sshdwf=" && echo ==)begin download file from server "&_
        				" && "&scpm&" "&ruser&"@"&rhost&":"&rtdir&"/ "&currDir&"\"&rtdir&"\"&_ 
        				" && "&sshm&" rm -rf ~/"&rtdir&";"""&_ 
        				" && echo ==)download file completed  ! " '�����ļ�������,ɾ����������ʱĿ¼
        
        'Wscript.echo(sshupf)
        'Wscript.echo(sshdbd)
        'Wscript.echo(sshappd)
        'Wscript.echo(sshdwf)
    	spt=cmds&sshupf&sshdbd&sshappd&sshdwf
    	
    	
    	'Wscript.Echo(spt)
    	'Wscript.Echo(replace(spt,"&&",vbcrlf))
    	'Wscript.quit
    	ret=ws.run(spt,1,true) 'ִ����������
    	
		'set sh=CreateObject("Shell.Application")
		'sh.ShellExecute "cmd","/k "&prompt1&" && "&sshrm1&" && "&scpu1&" && "&scpu2&" && "&scpu3
    	
    	'Set logObj = fso.opentextfile(currdir+"\exc.log", 2, True, -1)    ' ������ļ�. ForWriting, TristateTrue.
    	'logObj.write replace(spt,"&&",vbcrlf)    ' ��־.
	  
    	'logObj.Close    ' �ر�����ļ�.
    	
    
        condir=currDir & "\"&rtDir&"\code"
	 	if fso.folderexists(condir) then  	
	        '�����ļ�
	       copydir fso,condir,currDir&"\code"
		end if
		
	    dbret=0
    	condir=currDir & "\"&rtDir&"\"&currDate
	 	if fso.folderexists(condir) then  	
	        '�����ļ�
	        dbret=dirscan(fso,condir,currDir&"\code\db")
		end if
		
		appret=0
    	condir=currDir & "\"&rtDir&"\code"
	 	if fso.folderexists(condir) then  	
	        '�����ļ�
	        appret=dirscan(fso,condir,currDir&"\code")
		end if
        if dbcnt>0 then
        	fso.deletefile(currDir&"\"&dblist)
        end if
        if appcnt>0 then
        	fso.deletefile(currDir&"\"&applist)
        end if
        
        Set fso=Nothing
        Msgbox Date&" "&Time&",�������ݿ��ļ�:"&dbret&",���س����ļ�:"&appret
        
End Sub

' Run
Call dotest()