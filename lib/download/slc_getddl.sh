#!/bin/ksh

if [ $# -ne 5 ]
then
    echo ""
    echo "USAGE: $0 database dbuser dbpasswd job_tp params"
    echo "����˵��:"
    echo "    database: ���ݿ���"
    echo "    dbuser:   ���ݿ��û���"
    echo "    dbpasswd: ���ݿ�����"
    echo "    job_tp:   ORA_SQL_TMP|ORA_TABLE_ONLY|ORA_VIEW|ORA_PROCEDURE|ORA_FUNCTION|ORA_PACKAGE_SPEC|ORA_PACKAGE_BODY|ORA_SEQUENCE|ORA_SYNONYM|ORA_TRIGGER|ORA_MATERIALIZED_VIEW|ORA_TYPE_SPEC|ORA_TYPE_BODY|ORA_JAVA_SOURCE"
    echo "    params:   schema.objname"
    echo ""
    exit 1
fi

database=$1
dbuser=$2
dbpasswd=$3
job_tp=$4
params=$5

curr_dir=`pwd`
curr_dt=`date +%Y%m%d`

logdir="${curr_dir}/log"
logfile="$logdir/slc_getddl.sh.log.$$"
target_file_dir="${curr_dir}/${curr_dt}"

mkdir -p ${logdir}
if [ $? -ne 0 ]
then
    echo "ERROR: mkdir -p ${logdir}"
    exit 1
fi

mkdir -p ${target_file_dir}
if [ $? -ne 0 ]
then
    echo "ERROR: mkdir -p ${target_file_dir}"
    exit 1
fi

spool_linesize="30000"
spool_long="999999"
spool_format="a50000"
run_flag="Y"

ECHO_SCREEN_LOG()
{
    echo "[$$] $*"
}

ECHO_ERROR_LOG()
{
    echo "[$$] $* "
}

SpoolSqlFileHead()
{
    if [ $# -ne 4 ]
    then
        ECHO_ERROR_LOG "USAGE: SpoolSqlFileHead ExeSqlFile Sqlfile_nm OnOffFlag TermOutFlag"
        ECHO_ERROR_LOG "    ExeSqlFile: SQLִ���ļ�"
        ECHO_ERROR_LOG "    Sqlfile_nm: ����ļ�"
        ECHO_ERROR_LOG "    OnOffFlag:  ��ϸ��־�����־(on|off)"
        ECHO_ERROR_LOG "    TermOutFlag:�ն������־(Y|N)"
        return 1
    fi

    ExeSqlFile=$1
    Sqlfile_nm=$2
    OnOffFlag=$3
    TermOutFlag=$4

    if [ "$OnOffFlag" != "on" -a "$OnOffFlag" != "off" ]
    then
        ECHO_ERROR_LOG "ERROR: SpoolSqlFileHead OnOffFlag��������"
        return 1
    fi

    if [ "$TermOutFlag" = "Y" ]
    then
        term_out_flag="on"
    elif [ "$TermOutFlag" = "N" ]
    then
        term_out_flag="off"
    else
        ECHO_ERROR_LOG "ERROR: SpoolSqlFileHead TermOutFlag��������"
        return 1
    fi

    cat >${ExeSqlFile} <<EOF
        WHENEVER OSERROR EXIT 255 ROLLBACK;
        WHENEVER SQLERROR EXIT 255 ROLLBACK;
        set sqlbl on;
        set define off;
        set pagesize 0;
        set termout ${term_out_flag};
        set echo ${OnOffFlag};
        set feedback ${OnOffFlag};
        set heading ${OnOffFlag};
        set trimout on;
        set trimspool on;
        set verify off;
        set linesize ${spool_linesize};
        set long ${spool_long};
        col c1 format ${spool_format};
        spool $Sqlfile_nm;
        EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true);
EOF
}

SpoolSqlFileEnd()
{
    if [ $# -ne 1 ]
    then
        ECHO_ERROR_LOG "USAGE: SpoolSqlFileEnd ExeSqlFile"
        ECHO_ERROR_LOG "    ExeSqlFile: SQLִ���ļ�"
        return 1
    fi

    ExeSqlFile=$1

    cat >>${ExeSqlFile} <<EOF
        spool off;
        quit;
EOF
}

res=0
case $job_tp in
ORA_SQL_TMP|ORA_TABLE_ONLY|ORA_VIEW|ORA_PROCEDURE|ORA_FUNCTION|ORA_PACKAGE_SPEC|ORA_PACKAGE_BODY|ORA_SEQUENCE|ORA_SYNONYM|ORA_TRIGGER|ORA_MATERIALIZED_VIEW|ORA_TYPE_SPEC|ORA_TYPE_BODY|ORA_JAVA_SOURCE)
    LOGIN_STR="${dbuser}/${dbpasswd}@${database}"
    ORACLE_USR=`echo ${dbuser}|tr [a-z] [A-Z]`
    schema=`echo ${params}|awk -F'.' '{print $1}'|tr [a-z] [A-Z]`
    objname=`echo ${params}|awk -F'.' '{print $2}'|tr [a-z] [A-Z]`
    if [ "${schema}" = "" -o "${objname}" = "" ]
    then
        ECHO_ERROR_LOG "ERROR: params������ʽ����"
        return 1
    fi
    exesqlfile="$logdir/${objname}_exe_ddl.sql.$$"
    tmpfile="$logdir/${objname}_tmp.$$"
    
    ECHO_SCREEN_LOG "[${schema}.${objname}]"
    
    if [ "$job_tp" = "ORA_SQL_TMP" -o "$job_tp" = "ORA_TABLE_ONLY" ]
    then
        SPOOL_TYPE="TABLE"
        file_nm="$target_file_dir/CREATE_${SPOOL_TYPE}_${schema}_${objname}.sql"
    
        semicolon_cnt=1
    
        #��ȡCONSTRAINT����
        SpoolSqlFileHead ${exesqlfile} ${tmpfile} off Y
        echo "select count(*) from dba_constraints where owner='${schema}' and table_name='${objname}';" >>${exesqlfile}
        SpoolSqlFileEnd ${exesqlfile}
        constraints_cnt=`sqlplus -L -S ${LOGIN_STR} @${exesqlfile}|tr -d '\t| '`
        if [[ $constraints_cnt != +([0-9]) ]] || [ $constraints_cnt -eq 255 ]
        then
            ECHO_ERROR_LOG "ERROR: ��ȡ��[${objname}]CONSTRAINT����ʧ��[${constraints_cnt}]"
            res=1
        else
            semicolon_cnt=`expr $semicolon_cnt + $constraints_cnt`
    
            #��ȡ��������
            SpoolSqlFileHead ${exesqlfile} ${tmpfile} off Y
            echo "select count(*) from dba_indexes a where table_owner='${schema}' and table_name='${objname}' and generated='N' and not exists(select 1 from dba_constraints b where owner='${schema}' and table_name='${objname}' and b.index_owner=a.owner and b.index_name=a.index_name);" >>${exesqlfile}
            SpoolSqlFileEnd ${exesqlfile}
            index_cnt=`sqlplus -L -S ${LOGIN_STR} @${exesqlfile}|tr -d '\t| '`
            if [[ $index_cnt != +([0-9]) ]] || [ $index_cnt -eq 255 ]
            then
                ECHO_ERROR_LOG "ERROR: ��ȡ��[${objname}]��������ʧ��[${index_cnt}]"
                res=1
            else
                semicolon_cnt=`expr $semicolon_cnt + $index_cnt`
    
                #��ȡCOMMENT����
                SpoolSqlFileHead ${exesqlfile} ${tmpfile} off Y
                echo "select sum(cnt) from (select count(*) cnt from dba_col_comments where owner='${schema}' and table_name='${objname}' and comments is not NULL union all select count(*) cnt from dba_tab_comments where owner='${schema}' and table_name='${objname}' and comments is not NULL union all select count(*) cnt from dba_mview_comments where mview_name='${objname}' and comments is not NULL);" >>${exesqlfile}
                SpoolSqlFileEnd ${exesqlfile}
                comment_cnt=`sqlplus -L -S ${LOGIN_STR} @${exesqlfile}|tr -d '\t| '`
                if [[ $comment_cnt != +([0-9]) ]] || [ $comment_cnt -eq 255 ]
                then
                    ECHO_ERROR_LOG "ERROR: ��ȡ��[${objname}]COMMENT����ʧ��[${comment_cnt}]"
                    res=1
                else
                    semicolon_cnt=`expr $semicolon_cnt + $comment_cnt` 
    
                    #��ȡȨ�޸���
                    SpoolSqlFileHead ${exesqlfile} ${tmpfile} off Y
                    echo "select count(*) from dba_tab_privs where owner='${schema}' and table_name='${objname}';" >>${exesqlfile}
                    SpoolSqlFileEnd ${exesqlfile}
                    grant_cnt=`sqlplus -L -S ${LOGIN_STR} @${exesqlfile}|tr -d '\t| '`
                    if [[ $grant_cnt != +([0-9]) ]] || [ $grant_cnt -eq 255 ]
                    then
                        ECHO_ERROR_LOG "ERROR: ��ȡ��[${objname}]GRANT����ʧ��[${grant_cnt}]"
                        res=1
                    else
                        semicolon_cnt=`expr $semicolon_cnt + $grant_cnt`
    
                        #��ȡ�������
                        SpoolSqlFileHead ${exesqlfile} ${file_nm} off N
                        echo "EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'STORAGE',FALSE);" >>${exesqlfile}
                        echo "EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'CONSTRAINTS',FALSE);" >>${exesqlfile}
                        echo "EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'REF_CONSTRAINTS',FALSE);" >>${exesqlfile}
                        echo "EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'CONSTRAINTS_AS_ALTER',FALSE);" >>${exesqlfile}
                        ECHO_SCREEN_LOG "--��ȡCREATE���"
                        ECHO_SCREEN_LOG "echo \"select DBMS_METADATA.get_ddl(OBJECT_TYPE,OBJECT_NAME,OWNER) c1 from dba_objects where OWNER='${schema}' and OBJECT_TYPE='TABLE' and OBJECT_NAME='${objname}';\" >>${exesqlfile}"
                        echo "select DBMS_METADATA.get_ddl(OBJECT_TYPE,OBJECT_NAME,OWNER) c1 from dba_objects where OWNER='${schema}' and OBJECT_TYPE='TABLE' and OBJECT_NAME='${objname}';" >>${exesqlfile}
                        if [ $constraints_cnt -ne 0 ]
                        then
                            ECHO_SCREEN_LOG "--��ȡCONSTRAINT"
                            ECHO_SCREEN_LOG "echo \"select (case when constraint_type='R' then DBMS_METADATA.get_ddl('REF_CONSTRAINT',CONSTRAINT_NAME,OWNER) else DBMS_METADATA.get_ddl('CONSTRAINT',CONSTRAINT_NAME,OWNER) end) c1 from dba_constraints where owner='${schema}' and table_name='${objname}' order by owner,table_name,CONSTRAINT_NAME;\" >>${exesqlfile}"
                            echo "select (case when constraint_type='R' then DBMS_METADATA.get_ddl('REF_CONSTRAINT',CONSTRAINT_NAME,OWNER) else DBMS_METADATA.get_ddl('CONSTRAINT',CONSTRAINT_NAME,OWNER) end) c1 from dba_constraints where owner='${schema}' and table_name='${objname}' order by owner,table_name,CONSTRAINT_NAME;" >>${exesqlfile}
                        fi
                        if [ $index_cnt -ne 0 ]
                        then
                            ECHO_SCREEN_LOG "--��ȡINDEX"
                            ECHO_SCREEN_LOG "echo \"select DBMS_METADATA.get_ddl('INDEX',INDEX_NAME,OWNER) c1 from dba_indexes a where table_owner='${schema}' and table_name='${objname}' and generated='N' and not exists(select 1 from dba_constraints b where owner='${schema}' and table_name='${objname}' and b.index_owner=a.owner and b.index_name=a.index_name) order by table_owner,table_name,owner,index_name;\" >>${exesqlfile}"
                            echo "select DBMS_METADATA.get_ddl('INDEX',INDEX_NAME,OWNER) c1 from dba_indexes a where table_owner='${schema}' and table_name='${objname}' and generated='N' and not exists(select 1 from dba_constraints b where owner='${schema}' and table_name='${objname}' and b.index_owner=a.owner and b.index_name=a.index_name) order by table_owner,table_name,owner,index_name;" >>${exesqlfile}
                        fi
                        if [ $comment_cnt -ne 0 ]
                        then
                            ECHO_SCREEN_LOG "--��ȡCOMMENT"
                            ECHO_SCREEN_LOG "echo \"select DBMS_METADATA.get_dependent_ddl('COMMENT','${objname}','${schema}') c1 from dual;\" >>${exesqlfile}"
                            echo "select DBMS_METADATA.get_dependent_ddl('COMMENT','${objname}','${schema}') c1 from dual;" >>${exesqlfile}
                        fi
                        if [ $grant_cnt -ne 0 ]
                        then
                            ECHO_SCREEN_LOG "--��ȡGRANT"
                            ECHO_SCREEN_LOG "echo \"select DBMS_METADATA.get_dependent_ddl('OBJECT_GRANT','${objname}','${schema}') c1 from dual;\" >>${exesqlfile}"
                            echo "select DBMS_METADATA.get_dependent_ddl('OBJECT_GRANT','${objname}','${schema}') c1 from dual;" >>${exesqlfile}
                        fi
       
                        SpoolSqlFileEnd ${exesqlfile}
                        ECHO_SCREEN_LOG "sqlplus -L -S ${dbuser}/******@${database} @${exesqlfile} >>${logfile} 2>&1"
                        echo "------>" >>${logfile}
                        cat ${exesqlfile} >>${logfile}
                        echo "<------" >>${logfile}
                        if [ "$run_flag" = "Y" ]
                        then
                            sqlplus -L -S ${LOGIN_STR} @${exesqlfile} >>${logfile} 2>&1
                            res=$?
                            if [ $res -ne 0 ]
                            then
                                ECHO_ERROR_LOG "ERROR: sqlplus -L -S ${LOGIN_STR} @${exesqlfile}ִ��ʧ��"
                            else
                                #�ж��ļ���С
                                size=`cat "${file_nm}"|wc -c`
                                if [ $size -eq 0 ]
                                then
                                    ECHO_ERROR_LOG "ERROR: ���󲻴���"
                                    res=1
                                else
                                    #ͨ���ֺŸ�����һ���жϻ�ȡ�Ľ�������Ƿ��б��ض�
                                    real_cnt=`grep ';$' ${file_nm}|wc -l`
                                    if [ $real_cnt -ne $semicolon_cnt ]
                                    then
                                        ECHO_ERROR_LOG "ERROR: ��ȡ[${schema}][${objname}]���ʧ��(���ڽض����)"
                                        ECHO_ERROR_LOG "CONSTRAINT:${constraints_cnt},INDEX:${index_cnt},COMMENT:${comment_cnt},GRANT:${grant_cnt}"
                                        ECHO_ERROR_LOG "�����SPOOL_LINESIZE,SPOOL_LONG,SPOOL_FORMAT����������С������"
                                        res=1
                                    fi

                                    #��SEGMENT CREATION DEFERRED�滻ΪSEGMENT CREATION IMMEDIATE
                                    sed 's/SEGMENT CREATION DEFERRED/SEGMENT CREATION IMMEDIATE/g' ${file_nm} > ${file_nm}.tmp
                                    mv ${file_nm}.tmp ${file_nm}
                                fi
                            fi
                        else
                            touch ${file_nm}
                        fi
                    fi
                fi
            fi
        fi
    else
        SPOOL_TYPE=`echo "${job_tp}"|sed 's/ORA_//g'`
        if [ "${job_tp}" = "ORA_PACKAGE_SPEC" ]
        then
            file_nm="$target_file_dir/CREATE_${SPOOL_TYPE}_${schema}_${objname}.pls"
        elif [ "${job_tp}" = "ORA_PACKAGE_BODY" ]
        then
            file_nm="$target_file_dir/CREATE_${SPOOL_TYPE}_${schema}_${objname}.plb"
        else
            file_nm="$target_file_dir/CREATE_${SPOOL_TYPE}_${schema}_${objname}.sql"
        fi
    
        SpoolSqlFileHead ${exesqlfile} ${file_nm} off N
        if [ "${job_tp}" = "ORA_PACKAGE_SPEC" -o "${job_tp}" = "ORA_TYPE_SPEC" ]
        then
            objtype=`echo "${SPOOL_TYPE}"|sed 's/_SPEC//g'`
        elif [ "${job_tp}" = "ORA_PACKAGE_BODY" -o "${job_tp}" = "ORA_TYPE_BODY" -o "${job_tp}" = "ORA_MATERIALIZED_VIEW" -o "${job_tp}" = "ORA_JAVA_SOURCE" ]
        then
            objtype=`echo "${SPOOL_TYPE}"|sed 's/_/ /g'`
        else
            objtype="${SPOOL_TYPE}"
        fi

        if [ "${job_tp}" = "ORA_JAVA_SOURCE" ]
        then
            #DBMS_METADATA.get_ddl��ȡ��JAVA SOURCE��ʽ����,��Ϊͨ��dba_source��ȡ
            ECHO_SCREEN_LOG "echo \"select 'CREATE OR REPLACE AND COMPILE ${objtype} NAMED ${schema}.${objname} AS' from dual union all select TEXT from (select TEXT from dba_source where TYPE='${objtype}' and OWNER='${schema}' and NAME='${objname}' order by LINE) union all select '/' from dual;\" >>${exesqlfile}"
            echo "select 'CREATE OR REPLACE AND COMPILE ${objtype} NAMED ${schema}.${objname} AS' from dual union all select TEXT from (select TEXT from dba_source where TYPE='${objtype}' and OWNER='${schema}' and NAME='${objname}' order by LINE) union all select '/' from dual;" >>${exesqlfile}
        elif [ "${job_tp}" = "ORA_TYPE_BODY" ]
        then
            #���Զ�����������ͷ������ʱ,DBMS_METADATA.get_ddl�ᱨ��,��Ϊͨ��dba_source��ȡ
            ECHO_SCREEN_LOG "echo \"select 'CREATE OR REPLACE '||TEXT from dba_source where TYPE='${objtype}' and OWNER='${schema}' and NAME='${objname}' and LINE=1 union all select TEXT from (select TEXT from dba_source where TYPE='${objtype}' and OWNER='${schema}' and NAME='${objname}' and LINE>1 order by LINE) union all select '/' from dual;\" >>${exesqlfile}"
            echo "select 'CREATE OR REPLACE '||TEXT from dba_source where TYPE='${objtype}' and OWNER='${schema}' and NAME='${objname}' and LINE=1 union all select TEXT from (select TEXT from dba_source where TYPE='${objtype}' and OWNER='${schema}' and NAME='${objname}' and LINE>1 order by LINE) union all select '/' from dual;" >>${exesqlfile}
        else
            ECHO_SCREEN_LOG "echo \"select DBMS_METADATA.get_ddl('${SPOOL_TYPE}',object_name,OWNER) c1 from dba_objects where OWNER='${schema}' and OBJECT_TYPE='${objtype}' and OBJECT_NAME='$objname';\" >>${exesqlfile}"
            echo "select DBMS_METADATA.get_ddl('${SPOOL_TYPE}',object_name,OWNER) c1 from dba_objects where OWNER='${schema}' and OBJECT_TYPE='${objtype}' and OBJECT_NAME='$objname';" >>${exesqlfile}
        fi

        SpoolSqlFileEnd ${exesqlfile}
        ECHO_SCREEN_LOG "sqlplus -L -S ${dbuser}/******@${database} @${exesqlfile} >>${logfile} 2>&1"
        echo "------>" >>${logfile}
        cat ${exesqlfile} >>${logfile}
        echo "<------" >>${logfile}
        if [ "$run_flag" = "Y" ]
        then
            sqlplus -L -S ${LOGIN_STR} @${exesqlfile} >>${logfile} 2>&1
            res=$?
            if [ $res -ne 0 ]
            then
                ECHO_ERROR_LOG "ERROR: sqlplus -L -S ${LOGIN_STR} @${exesqlfile}ִ��ʧ��"
            else
                #�ж϶����Ƿ����
                #ORA_JAVA_SOURCE,ORA_TYPE_BODY ͨ�������ж�,����ͨ���ļ���С�ж�
                size=`cat "${file_nm}"|wc -c`
                linecnt=`cat "${file_nm}"|wc -l`
                if [ \( "${job_tp}" = "ORA_JAVA_SOURCE" -a $linecnt -eq 2 \) -o \( "${job_tp}" = "ORA_TYPE_BODY" -a $linecnt -eq 1 \) -o $size -eq 0 ]
                then
                    ECHO_ERROR_LOG "ERROR: ���󲻴���"
                    res=1
                else
                    #��һ���ж��Ƿ�ض�
                    if [ "${job_tp}" = "ORA_VIEW" -o "${job_tp}" = "ORA_SEQUENCE" -o "${job_tp}" = "ORA_SYNONYM" -o "${job_tp}" = "ORA_MATERIALIZED_VIEW" ]
                    then
                        #ORA_VIEW,ORA_SEQUENCE,ORA_SYNONYM,ORA_MATERIALIZED_VIEW ͨ������Ƿ��ԷֺŽ�β�ж��Ƿ��б��ض�
                        check_flag=`sed 's/ //g' ${file_nm}|grep -v ^$|tail -1|grep ';$'|wc -l`
                    elif [ "${job_tp}" = "ORA_TRIGGER" ]
                    then
                        #ORA_TRIGGER ͨ������Ƿ���ABLE;��β�ж��Ƿ��б��ض�
                        check_flag=`sed 's/ //g' ${file_nm}|grep -v ^$|tail -1|grep 'ABLE;$'|wc -l`
                    else
                        #ORA_FUNCTION,ORA_PACKAGE_SPEC,ORA_PACKAGE_BODY,ORA_PROCEDURE,ORA_TYPE_SPEC,ORA_TYPE_BODY,ORA_JAVA_SOURCE ͨ������Ƿ���/��β�ж��Ƿ��б��ض�
                        check_flag=`sed 's/ //g' ${file_nm}|grep -v ^$|tail -1|grep '^/$'|wc -l`
                    fi
    
                    if [ ${check_flag} -ne 1 ]
                    then
                        ECHO_ERROR_LOG "ERROR: ��ȡ[${schema}][${objname}]���ʧ��(���ڽض����)"
                        ECHO_ERROR_LOG "�����SPOOL_LINESIZE,SPOOL_LONG,SPOOL_FORMAT����������С������"
                        res=1
                    fi

                    if [ "${job_tp}" = "ORA_SEQUENCE" ]
                    then
                        sed 's/START WITH [0-9]*//g' ${file_nm} > ${file_nm}.tmp
                        mv ${file_nm}.tmp ${file_nm}
                    fi
                fi
            fi
        else
            touch ${file_nm}
        fi
    fi

    if [ $res -eq 0 ]
    then
        rm ${logfile}
        rm ${exesqlfile}
        if [ "$job_tp" = "ORA_SQL_TMP" -o "$job_tp" = "ORA_TABLE_ONLY" ]
        then
            rm ${tmpfile}
        fi
    else
        cat ${file_nm} >> ${logfile}
        rm ${file_nm}
    fi
    ;;
*)
    res=1
    ECHO_ERROR_LOG "ERROR: ����[$job_tp]����ʶ��"
    ;;
esac

exit $res
