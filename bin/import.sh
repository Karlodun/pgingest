#!/bin/bash
my_path="`dirname \"$0\"`"              # relative
my_path="`( cd \"$my_path\" && pwd )`"  # absolutized and normalized
if [ -z "$my_path" ] ; then
  # error; for some reason, the path is not accessible
  # to the script (e.g. permissions re-evaled after suid)
  exit 1  # fail
fi
source "$my_path/db_conn.sh"
mkdir $my_path/../tmp/task_$1
cd $my_path/../tmp/task_$1
my_task=$1
{
# get import vars
import_type=$( psql "$db_conn" -t -q -A -c "select import_type from $g.import_source WHERE import_name= '$1';" )
source_encoding=$( psql "$db_conn" -t -q -A -c "select source_encoding from $g.import_source WHERE import_name= '$1';" )
csv_delimiter=$( psql "$db_conn" -t -q -A -c "select csv_delimiter from $g.import_source WHERE import_name= '$1';" )
tg_conn=$( psql "$db_conn" -t -q -A -c "select tg_conn from $g.tg_conn WHERE import_name= '$1';" )
echo "tg_conn:$tg_conn";

# create import task
task_id=$( psql "$db_conn" -t -q -A -c "INSERT INTO $g.task_board(import_name) VALUES ('$1') RETURNING task_id;" )
# if required clean up tasks manually: TRUNCATE TABLE public.task_board RESTART IDENTITY RESTRICT;

update_task () { $( psql "$db_conn" -t -q -A -c "UPDATE $g.task_board SET status='$1' WHERE task_id='$task_id';" ); echo $1;}

# if second argument is passed, use local path file, else download using link
if [ $# -eq 2 ] ;
    then 
        zcat $2 > raw_import 2>/dev/null || cat $2 > raw_import
    else 
        update_task 'downloading'
        $( psql "$db_conn" -t -q -A -c "select concat('curl ',download_link,' --output raw_import') from $g.import_source WHERE import_name= '$1';" )
fi

update_task 'pre import steps'
$( psql "$db_conn" -t -q -A -c "select pre_import_steps from $g.import_source WHERE import_name= '$1';" )

#fix any issues for files coming from windows
dos2unix raw_import

update_task 'prepare schemas'
psql "$tg_conn" -t -q -A -c "CREATE SCHEMA IF NOT EXISTS raw_import; GRANT USAGE ON SCHEMA raw_import to public;"
psql "$tg_conn" -t -q -A -c "$( psql "$db_conn" -t -q -A -c "SELECT sql_code from $g.runner_prepare_schemas WHERE import_name='$1';")"

case $import_type in
    ascii)
        update_task 'rotate raw tables'
        psql "$tg_conn" -t -q -A -c "DROP TABLE IF EXISTS raw_import.$1_$task_id; CREATE TABLE raw_import.$1_$task_id (tuples varchar);"
        
        update_task 'importing raw data'
        psql "$tg_conn" -t -q -A -c "\copy raw_import.$1_$task_id from $g.'raw_import' ENCODING $source_encoding delimiter '|' csv;"
        ;;
    csv) 
        has_headers=$( psql "$db_conn" -t -q -A -c "select case when has_headers then 'HEADER' else '' end from $g.import_source WHERE import_name='$1';" )
        if [[ "$has_headers" = "HEADER" ]]
            then {
                update_task 'creating headers from csv'
                csv_headers=$( head -1 raw_import | sed -e "s|$csv_delimiter|\" varchar, \"|g" | sed -e "s|^|\"|g" | sed -e "s|$|\" varchar|g" )
            }
            else {
                update_task 'creating virtual headers'
                csv_columns=$(head -1 raw_import | sed "s/[^$csv_delimiter]//g" | wc -c)
                csv_headers=''
                csv_column=0
                while [ $csv_column -lt $csv_columns ]; do
                    #csv_headers=$csv_headers'c'$csv_column" varchar$csv_delimiter "
                    csv_headers=$csv_headers'c'$csv_column" varchar, "
                    ((++csv_column))
                done
                csv_headers=${csv_headers%??}; # drop last comma
            }
        fi

        update_task 'rotate raw tables'
        psql "$tg_conn" -t -q -A -c "DROP TABLE IF EXISTS raw_import.$1_$task_id; CREATE TABLE raw_import.$1_$task_id ($csv_headers);"

        update_task 'importing raw data'
        psql "$tg_conn" -t -q -A -c "\copy raw_import.$1_$task_id from 'raw_import' ENCODING '$source_encoding' delimiter '$csv_delimiter' csv $has_headers;"
        ;;
    *) update_task 'error, unknown import type'
        ;;
esac

update_task 'imptask tables and rgx reports'
psql "$tg_conn" -t -q -A -c "$( psql "$db_conn" -t -q -A -c "SELECT concat(imptask_table,rgx_reports) FROM grimoire.code_gen WHERE import_name='$1' and task_id=$task_id;")"

update_task 'rotate runner table'
psql "$tg_conn" -t -q -A -c "DROP TABLE IF EXISTS raw_import.$1_runner_$task_id; CREATE TABLE raw_import.$1_runner_$task_id (runner_type varchar, runner_target varchar, runner_code varchar);"

update_task 'runner functions'
psql "$tg_conn" -t -q -A -c "$( psql "$db_conn" -t -q -A -c "SELECT runners FROM grimoire.code_gen WHERE import_name='$1' and task_id=$task_id;")"

update_task 'fill runner table'
psql "$tg_conn" -t -q -A -c "$( psql "$db_conn" -t -q -A -c "SELECT concat(fk_reports, table_recreator, table_filler, fk_setter) FROM grimoire.code_gen WHERE import_name='$1' and task_id=$task_id;")"

update_task "deleting raw files"
cd $my_path/..
rm -r $my_path/../tmp/task_$1

update_task "pre import procedures completed"
} > $my_path/../logs/$1 2>&1

echo $task_id
