#!/bin/ksh

if [ $# -ne 5 ]
then
    echo ""
    echo "USAGE: $0 database dbuser dbpasswd [-s schema|-f file_list]"
    echo "����˵��:"
    echo "    database:  ���ݿ���"
    echo "    dbuser:    ���ݿ��û���"
    echo "    dbpasswd:  ���ݿ�����"
    echo "    -s schema: ��ȡָ��schema�����ж���"
    echo "    -f file_list: ��ȡ�б��ļ����ж���(���ݸ�ʽ������|����)"
    echo "        ����: T-��V-��ͼ��P-�洢���̣�F-������PH-��ͷ��PB-���壬SEQ-���У�SYN-ͬ��ʣ�TRG-��������M-�ﻯ��ͼ"
    echo "        ����: ����ͼ���洢���̡���������ͷ�����塢���С�ͬ��ʡ����������ﻯ��ͼ"
    echo "          �磺T|DWMM.JOB_METADATA"
    echo ""
    exit 1
fi

spool_linesize="30000"
spool_long="999999"
spool_format="a50000"

SpoolSqlFileHead()
{
    if [ $# -ne 4 ]
    then
        echo "USAGE: SpoolSqlFileHead ExeSqlFile Sqlfile_nm OnOffFlag TermOutFlag"
        echo "    ExeSqlFile: SQLִ���ļ�"
        echo "    Sqlfile_nm: ����ļ�"
        echo "    OnOffFlag:  ��ϸ��־�����־(on|off)"
        echo "    TermOutFlag:�ն������־(Y|N)"
        return 1
    fi

    ExeSqlFile=$1
    Sqlfile_nm=$2
    OnOffFlag=$3
    TermOutFlag=$4

    if [ "$OnOffFlag" != "on" -a "$OnOffFlag" != "off" ]
    then
        echo "ERROR: SpoolSqlFileHead OnOffFlag��������"
        return 1
    fi

    if [ "$TermOutFlag" = "Y" ]
    then
        term_out_flag="on"
    elif [ "$TermOutFlag" = "N" ]
    then
        term_out_flag="off"
    else
        echo "ERROR: SpoolSqlFileHead TermOutFlag��������"
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
        echo "USAGE: SpoolSqlFileEnd ExeSqlFile"
        echo "    ExeSqlFile: SQLִ���ļ�"
        return 1
    fi

    ExeSqlFile=$1

    cat >>${ExeSqlFile} <<EOF
        spool off;
        quit;
EOF
}

database=$1
dbuser=$2
dbpasswd=$3

curr_dir=`pwd`
curr_dt=`date +%Y%m%d`

logdir="${curr_dir}/log"
logfile="$logdir/slc_getddl_all.sh.log.$$"
target_file_dir="${curr_dir}/${curr_dt}"
listfile="$logdir/list_tmp.$$"

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

if [ "$4" = "-s" ]
then
    schema=$5

    LOGIN_STR="${dbuser}/${dbpasswd}@${database}"
    schema=`echo ${schema}|tr [a-z] [A-Z]`

    exesqlfile="$logdir/list_exe_ddl.sql.$$"

    SpoolSqlFileHead ${exesqlfile} ${listfile} off N
    echo "select OBJECT_TYPE||'|'||OWNER||'.'||OBJECT_NAME from dba_objects where OWNER='${schema}';" >>${exesqlfile}
    SpoolSqlFileEnd ${exesqlfile}
    sqlplus -L -S ${LOGIN_STR} @${exesqlfile} >>${logfile} 2>&1
    res=$?
    if [ $res -ne 0 ]
    then
        echo "ERROR: sqlplus -L -S ${LOGIN_STR} @${exesqlfile}ִ��ʧ��"
        exit 1
    fi

    rm ${exesqlfile}
elif [ "$4" = "-f" ]
then
    src_listfile=$5
    if [ ! -f ${src_listfile} ]
    then
        echo "ERROR: ָ���б��ļ�������"
        exit 1
    fi

    cat ${src_listfile} > ${listfile}
else
    echo "ERROR: ����[$4]����ʶ��"
    exit 1
fi

while read line
do
    echo "${line}... \c"
    type=`echo ${line}|awk -F'|' '{print $1}'`
    sch_obj=`echo ${line}|awk -F'|' '{print $2}'`
    if [ "$type" = "TABLE" ]
    then
        type="ORA_SQL_TMP"
    elif [ "$type" = "PACKAGE" ]
    then
        type="ORA_PACKAGE_SPEC"
    elif [ "$type" = "PACKAGE BODY" ]
    then
        type="ORA_PACKAGE_BODY"
    elif [ "$type" = "MATERIALIZED VIEW" ]
    then
        type="ORA_MATERIALIZED_VIEW"
    else
        type="ORA_${type}"
    fi

    slc_getddl.sh "${database}" "${dbuser}" "${dbpasswd}" "${type}" "${sch_obj}" >>${logfile}
    if [ $? -ne 0 ]
    then
        echo "ERROR"
    else
        echo "OK"
    fi
done < ${listfile}
