#!/bin/bash
# the executable should be modded with 'setuid': chmod g+s
# best permission should be: 4111
# and check out: sudo -u username command

source <( psql service=pgingest -c "SELECT task_vars('$1');" ) # get import vars

# create import task
task_id=$( psql service=pgingest -c "SELECT new_task('$1');" )
# if required clean up tasks manually: TRUNCATE TABLE public.task_board RESTART IDENTITY RESTRICT; respective functionality will be implemented soon.
update_task () { echo $( psql service=pgingest -c "select update_task('$task_id','$1');" );}
mkdir -p ~pgingest/tmp/$1_$task_id
cd ~pgingest/tmp/$1_$task_id
{
# if second argument is passed, use local file, else download using link
if [ $# -eq 2 ] ;
    then 
        zcat $2 > raw_import 2>/dev/null || cat $2 > raw_import #try to unzip, else just cat
    else 
        update_task 'downloading'
        curl $download_link --output raw_import
fi

update_task 'pre import steps'; bash -c "$pre_import_steps";

update_task 'prepare target db'
psql service=pgingest -c "SELECT prep_code('$1');" > prep_code.sql

psql "$tg_conn" -f prep_code.sql

if $has_headers
    then {
        header='HEADER'
        update_task 'creating headers from csv'
        tg_columns=$( head -1 raw_import | sed -e "s|$csv_delimiter|\" varchar, \"|g" | sed -e "s|^|\"|g" | sed -e "s|$|\" varchar|g" )
        header='HEADER'
    }
    else {
        header=''
        update_task 'creating virtual headers'
        total_columns=$(head -1 raw_import | sed "s/[^$csv_delimiter]//g" | wc -c)
        tg_columns=''
        tg_column=0
        while [ $tg_column -lt $total_columns ]; do
            tg_columns=$tg_columns'c'$tg_column" varchar, "
            ((++tg_column))
        done
        tg_columns=${tg_columns%??}; # drop last comma
    }
fi

update_task 'prepare raw table'
psql "$tg_conn" -c "DROP TABLE IF EXISTS pgingest.$1_$task_id; CREATE TABLE pgingest.$1_$task_id ($tg_columns);"

update_task 'import raw data'
psql "$tg_conn" -c "\copy pgingest.$1_$task_id from 'raw_import' ENCODING '$source_encoding' delimiter '$csv_delimiter' csv $header;"

update_task 'pushing task code to target db'
psql service=pgingest -c "SELECT task_code($task_id);" > task_code.sql
psql "$tg_conn" -f task_code.sql

# cleanse task files
if ! $debugmode; then {
    update_task "deleting raw files";
    cd ~;
    rm -r ~pgingest/tmp/$1_$task_id;
}; fi;

update_task "pre import procedures completed"

} > ~pgingest/tmp/$1_$task_id/import.log 2>&1

echo $task_id
