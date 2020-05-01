#!/bin/bash
my_path="`dirname \"$0\"`"              # relative
my_path="`( cd \"$my_path\" && pwd )`"  # absolutized and normalized
if [ -z "$my_path" ] ; then
  # error; for some reason, the path is not accessible
  # to the script (e.g. permissions re-evaled after suid)
  exit 1  # fail
fi
source "$my_path/db_conn.sh"

db_res=$(psql "$db_conn" -t -q -c "select import_name from grimoire.import_source WHERE autofetch AND (last_update+download_interval)<=now();")
cd $my_path/../tmp/

for d in $db_res; do
    mkdir $d
    cd $d
    $( ../../bin/import.sh $d)
    # "updating timers for $d"
    psql "$db_conn" -t -q -c "UPDATE grimoire.import_source SET last_update = now() WHERE import_name= '$d';
    UPDATE grimoire.task_board SET status = 'completed' WHERE import_name= '$d';"
    # elaborate: run tasks in target DB automagically from here if auto fetch is on
    cd ..
    rm -r $d
done