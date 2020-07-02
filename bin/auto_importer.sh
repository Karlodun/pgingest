#!/bin/bash

db_res=$(psql service=pgingest -c "select import_name from grimoire.import_source WHERE autofetch AND (last_update+download_interval)<=now();")

for d in $db_res; do
    ~pgingest/bin/import.sh $d
    # "updating timers for $d"
    psql service=pgingest -c "UPDATE grimoire.import_source SET last_update = now() WHERE import_name= '$d';
    UPDATE grimoire.task_board SET status = 'completed' WHERE import_name= '$d';"
    # elaborate: run tasks in target DB automagically from here if auto fetch is on
    # dynamic code view for table recreation or table filling should check if the error reports are empty
    # if yes: run, if no: error.
    cd ..
    rm -r $d
done
