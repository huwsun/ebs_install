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

Function getResult(fso,logfile)
	getResult="E"
	Set f = fso.OpenTextFile(logfile, 1)
	Do Until f.AtEndOfStream
		strlog=f.ReadLine
		if instr( strlog,"install result : error!")>0 then
			getResult="E"	
		elseif instr( strlog,"install result : success!")>0 then
			getResult="S"	
	  	end if
	Loop
	f.Close
	Set f=Nothing
end function

' ����
Sub dotest
		'���в���
		'Set args = WScript.Arguments
		Set fso = CreateObject("Scripting.FileSystemObject")  
	
		'�����ļ������
		include "..\lib\lib.vbs"
		include "..\lib\lib_install.vbs"
		include "..\lib\aspjson.vbs"
		
    	currDir= GetCurrentFolderFullPath(fso,Wscript.ScriptFullName) 	
    	currPDir=fso.GetParentFolderName(currdir)
    	currDate=CStr(Year(Now()))&Right("0"&Month(Now()),2)&Right("0"&Day(Now()),2)
    	
		srcPath=InputBox("���������Ŀ¼��Ĭ��Ϊ��ǰĿ¼:","���������Ŀ¼",currdir)	
		if srcPath="" then
			Wscript.quit
		elseif Not fso.FolderExists(srcPath) Then
			MsgBox "Ŀ¼������:<" & histPath & ">"
			wscript.quit
	 	end if
    	
		'��ȡ��������,��ȡjson�����ļ�
		set data=readConfig(fso,"install_conn.cfg")
		set odb=data("db")
		set oahost=data("app")
		set langobj=data("lang")
		
    	dbsid=odb("sid")
    	dbuser=odb("user")
    	dbpw=odb("pwd")
    	cuxpw=odb("cuxpwd")
    	
		hostcount=oahost.count
		
		Set filedata = Collection()
    	filecnt=procFiles(fso,srcPath,currDir)
    	'Wscript.quit
    	appexist=0
    	dbexist=0
    	
		if fso.folderexists(currDir&"\code\app") then
			appexist=1
		end if
		if fso.folderexists(currDir&"\code\db") then
			dbexist=1
		end if
		if appexist=0 and dbexist=0 then
			Msgbox "Ŀ¼<" & srcPath & ">�²�������Ч�Ĵ����ļ���"
			Wscript.quit
		end if
		
    	rd=getRandom(1,100000)
    	
		logfile="exec.log"
		cmds="%comspec% /k"
		scpcm=currPDir&"\lib\pscp.exe -q -r  -pw [pwd]" 'ssh�ļ��ϴ�����������
		
    	sshcm=currPDir&"\lib\plink.exe -ssh  -pw [pwd] [user]@[host] """ 'ssh����
    	
		set ws=createobject("wscript.shell")

		renv=". ./setenv.sh;. [profile];" '��������
    	
    	sshpre="cd $HOME/[rtdir]; pwd; chmod +x ./*; "&renv&"echo ""NLS_LANG=$NLS_LANG"";"
    	
    	icount=0
    	resultstr="��װ�����"
    	For Each row in oahost
    		icount=icount+1
    		set ohost=oahost.item(row)
    		rtype=ohost("type")
    		rhost=ohost.item("host")
    		ruser=ohost.item("user")
    		rpwd=ohost.item("pwd")
    		
	    	instRes=""
    		if rtype="master" or appexist=1 then

	    		sshm=replace(sshcm,"[host]",rhost)
	    		sshm=replace(sshm,"[user]",ruser)
	    		sshm=replace(sshm,"[pwd]",rpwd)
	    		scpm=replace(scpcm,"[pwd]",rpwd)
	    		
	    		prefixhost=replace(rhost,".","_")
	    		rtdir="install_"&currDate&"_"&rd
	    		prompt="==("&rhost&"): "
	    	
			  	'ɾ�������ļ�Ŀ¼	
			  	condir=currDir & "\"&rtDir
			 	if fso.folderexists(condir) then  	
					fso.deletefolder(condir)
				end if
				
				rshtype=getShType(ws,sshm & "echo $0""")
				if rshtype ="ksh" then
			  		rprof="~/.profile"
			    elseif rshtype="bash" then
			    	rprof="~/.bash_profile"
			  	end if
			  	
				sshpre=replace(sshpre,"[profile]",rprof)
				sshpre=replace(sshpre,"[rtdir]",rtdir)
	    		
	    		'ɾ������Ŀ¼����������ʱĿ¼,�ϴ�ִ�нű�
		    	prm="echo  begin install process: && echo uploading file to server..... "
		    			  
		    	sshupf= sshm&" rm -rf ~/"&rtdir&"; mkdir ~/"&rtdir&";mkdir ~/"&rtdir&"/code;"""&_ 
		    			  " && "&scpm&" "&currPDir&"\lib\common\ "&ruser&"@"&rhost&":"&rtdir &_ 
		    			  " && "& scpm&" "&currPDir&"\lib\install\ "&ruser&"@"&rhost&":"&rtdir
		    			  
	  			if appexist=1 then
	  			  sshupf=sshupf&" && "&scpm&" "&currDir&"\code\app "&ruser&"@"&rhost&":"&rtdir&"/code"
	  			end if
	  			  
		    	if rtype="master" and dbexist=1 then
		    		sshupf=sshupf&" && "&scpm&" "&currDir&"\code\db "&ruser&"@"&rhost&":"&rtdir&"/code"
		    	end if	
		    	
		    	sshupf=prm &" && "&sshupf&" && echo upload file successful ! " 
			
		    	prm=" && echo begin execute install: "
		    	sshinst=sshm&sshpre&"perl install.pl installpath=$HOME/"&rtdir&" cfgfile=$HOME/"&rtdir&"/install.cfg "&_
		  						" appsusr="&dbuser&" appspwd="&dbpw&" dbschemapwd="&cuxpw&" logfile=$HOME/"&rtdir&"/"&prefixhost&"_install.log;"""
		  	    sshinst=prm&" && "&sshinst&" && echo execute install completed " 'ִ�а�װ
		    		
		        prm=" && echo begin download file from server "
		        sshdwf=		scpm&" "&ruser&"@"&rhost&":"&rtdir&"/"&prefixhost&"_install.log "&currDir&"\"&_ 
		        				" && "&sshm&" rm -rf ~/"&rtdir&";"""
		        sshdwf=prm&" && "&sshdwf&" && echo download file completed  ! " '������־�ļ�������,ɾ����������ʱĿ¼
		        
		        'Wscript.echo(sshupf)
		        'Msgbox (sshinst)
		        'Wscript.echo(sshdwf)
		    	spt=cmdproc(sshupf&sshinst&sshdwf,"",1,prompt)
		   
		    	'Wscript.Echo(replace(spt,"&&",vbcrlf))
		    	'Wscript.quit
		    	'ret=ws.run(spt,1,true) 'ִ����������
		    	exec spt
		    	
		    	instres=getResult(fso,currdir&"\"&prefixhost&"_install.log")		
		    else
		    	resultstr=resultstr&chr(10)&"Ӧ�ýڵ�("&rhost&")���谲װ"
	    	end if	    	
    		msgtype=0
	    	if instRes="S" then
    			msgstr="Ӧ�ýڵ�("&rhost&")��װ�ɹ���"
    			resultstr=resultstr&chr(10)&msgstr
    		elseif instRes="E" then
    			msgstr="Ӧ�ýڵ�("&rhost&")��װʧ�ܣ���ϸ��Ϣ������־�ļ���"
    			resultstr=resultstr&chr(10)&msgstr
    			if hostcount>icount then
    				msgstr=msgstr&chr(10)&"�Ƿ������װ����ڵ�?"
    				msgtype=4 
    			end if
    			
    			setnum = MsgBox(msgstr,msgtype)
	  			if setnum=7 then
	  				Exit for
	  			end if
  			end if
  			
  			
    	Next
    	
    	Msgbox(resultstr)
    
        Set fso=Nothing
        
End Sub

' Run
Call dotest()