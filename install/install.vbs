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
		
		Set fso = CreateObject("Scripting.FileSystemObject")  
		Set f = fso.OpenTextFile("install_conn.cfg", 1)
		strJson = f.ReadAll
		f.Close
		Set f=Nothing
		    
		'�����ļ������
		include "..\lib\lib.vbs"
		include "..\lib\aspjson.vbs"
		
		
		'��ȡ��������
		Set oJson=New aspJSON
		
		oJson.loadJSON(strJson)
		set odb=oJson.data("db")
		set oahost=oJson.data("app")
		
    	dbsid=odb("sid")
    	dbuser=odb("user")
    	dbpw=odb("pwd")
    	cuxpw=odb("cuxpwd")
    	
		hostcount=oahost.count

    	currDir= GetCurrentFolderFullPath(fso) 	
    	currPDir=fso.GetParentFolderName(currdir)
    	currDate=CStr(Year(Now()))&Right("0"&Month(Now()),2)&Right("0"&Day(Now()),2)
    	
    	dim maxB,minB
		maxB=10000
		minb=1
		'Randomize
		rd=Int((maxB-minB+1)*Rnd+minB)
    	
    	'Msgbox "begin:"&currDate&","&Date&" "&Time
    	
		
		cmds="%comspec% /c"
		scpcm=currPDir&"\lib\pscp.exe -q -r  -pw [pwd]" 'ssh�ļ��ϴ�����������
		
    	sshcm=currPDir&"\lib\plink.exe -ssh  -pw [pwd] [user]@[host] """ 'ssh����
    	
		set ws=createobject("wscript.shell")

		renv=". ./setenv.sh;" '��������
    	
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
    		sshm=replace(sshcm,"[host]",rhost)
    		sshm=replace(sshm,"[user]",ruser)
    		sshm=replace(sshm,"[pwd]",rpwd)
    		scpm=replace(scpcm,"[pwd]",rpwd)
    		
  		
	    	 		
    		prefixhost=replace(rhost,".","_")
    		rtdir="install_"&currDate&"_"&rd
    		prompt="==("&rhost&")== "
    	
		  	'ɾ�������ļ�Ŀ¼	
		  	condir=currDir & "\"&rtDir
		 	if fso.folderexists(condir) then  	
				fso.deletefolder(condir)
			end if
			
			sshpre=replace(sshpre,"[rtdir]",rtdir)
    		
    		'ɾ������Ŀ¼����������ʱĿ¼,�ϴ�ִ�нű�
	    	sshupf=" echo "&prompt&"begin install process: "&_
	    			  " && echo "&prompt&"uploading file to server..... "&_
	    			  " && "&sshm&" rm -rf ~/"&rtdir&"; mkdir ~/"&rtdir&";mkdir ~/"&rtdir&"/code;"""&_ 
	    			  " && "& scpm&" "&currPDir&"\lib\common\ "&ruser&"@"&rhost&":"&rtdir &_ 
	    			  " && "& scpm&" "&currPDir&"\lib\install\ "&ruser&"@"&rhost&":"&rtdir &_ 
	    			  " && "&scpm&" "&currDir&"\code\app "&ruser&"@"&rhost&":"&rtdir&"/code"
	    			  
	    	if rtype="master" then
	    		sshupf=sshupf&" && "&scpm&" "&currDir&"\code\db "&ruser&"@"&rhost&":"&rtdir&"/code"
	    	end if	
	    	
	    	sshupf=sshupf&" && echo "&prompt&"upload file successful ! " 
		
	    	sshinst=" && echo "&prompt&"begin execute install: "&_
	    					" && "&sshm&sshpre&"perl install.pl installpath=$HOME/"&rtdir&" cfgfile=$HOME/"&rtdir&"/install.cfg "&_
	  						" appsusr="&dbuser&" appspwd="&dbpw&" dbschemapwd="&cuxpw&" logfile=$HOME/"&rtdir&"/"&prefixhost&"_install.log;"""&_ 
	  						" && echo "&prompt&"execute install completed " 'ִ�а�װ
	    		
	    	
	        sshdwf=" && echo "&prompt&"begin download file from server "&_
	        				" && "&scpm&" "&ruser&"@"&rhost&":"&rtdir&"/"&prefixhost&"_install.log "&currDir&"\"&_ 
	        				" && "&sshm&" rm -rf ~/"&rtdir&";"""&_ 
	        				" && echo "&prompt&"download file completed  ! " '������־�ļ�������,ɾ����������ʱĿ¼
	        
	        'Wscript.echo(sshupf)
	        'Wscript.echo(sshinst)
	        'Wscript.echo(sshdwf)
	    	spt=cmds&sshupf&sshinst&sshdwf
	   
	    	'Wscript.Echo(spt)
	    	'Wscript.Echo(replace(spt,"&&",vbcrlf))
	    	'Wscript.quit
	    	ret=ws.run(spt,1,true) 'ִ����������
	    	
	    	instres=getResult(fso,currdir&"\"&prefixhost&"_install.log")		    	
    		msgtype=0
	    	if instres="S" then
    			msgstr="Ӧ�ýڵ�("&rhost&")��װ�ɹ���"
    			resultstr=resultstr&chr(10)&msgstr
    		elseif instres="E" then
    			msgstr="Ӧ�ýڵ�("&rhost&")��װʧ�ܣ���ϸ��Ϣ������־�ļ���"
    			resultstr=resultstr&chr(10)&msgstr
    			if hostcount>icount then
    				msgstr=msgstr&chr(10)&"�Ƿ������װ����ڵ�?"
    				msgtype=4 
    			end if
  			end if
  			
  			setnum = MsgBox(msgstr,msgtype)
  			if setnum=7 then
  				Exit for
  			end if
    	Next
    	
    	Msgbox(resultstr)
    
        Set fso=Nothing
        
End Sub

' Run
Call dotest()