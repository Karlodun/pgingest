GRANT USAGE ON SCHEMA pgingest TO public;

CREATE OR REPLACE VIEW pgingest.session_roles
AS WITH RECURSIVE cte AS (
    SELECT pg_roles.oid, pg_roles.rolname AS mr
    FROM pg_roles
    WHERE pg_roles.rolname = SESSION_USER
    UNION
    SELECT m.roleid,pgr.rolname
    FROM cte cte_1
    JOIN pg_auth_members m ON m.member = cte_1.oid
    JOIN pg_roles pgr ON pgr.oid = m.roleid
) SELECT array_agg(DISTINCT cte.mr) AS roles FROM cte;

CREATE OR REPLACE VIEW pgingest.current_roles
AS WITH RECURSIVE cte AS (
    SELECT pg_roles.oid, pg_roles.rolname AS mr
    FROM pg_roles
    WHERE pg_roles.rolname = CURRENT_USER
    UNION
    SELECT m.roleid,pgr.rolname
    FROM cte cte_1
    JOIN pg_auth_members m ON m.member = cte_1.oid
    JOIN pg_roles pgr ON pgr.oid = m.roleid
) SELECT array_agg(DISTINCT cte.mr) AS roles FROM cte;

GRANT SELECT ON pgingest.session_roles, pgingest.current_roles TO public;

CREATE TABLE pgingest.import_source (
    import_name varchar PRIMARY KEY,
    download_link varchar,
    download_interval interval,
    last_update date,
    description varchar,
    automate bool NOT NULL DEFAULT false,
    debugmode bool NOT NULL DEFAULT false,
    target_host varchar NOT NULL DEFAULT 'localhost' CHECK (trim(target_host) <> ''),
    target_port int2 NOT NULL DEFAULT 5432 CHECK (target_port BETWEEN 1 AND 65535),
    target_database varchar NOT NULL DEFAULT 'postgres' CHECK (trim(target_database) <> ''),
    source_encoding varchar NOT NULL DEFAULT 'UTF8' CHECK (trim(source_encoding) <> ''),
    pre_import_steps text,
    has_headers bool NOT NULL DEFAULT false,
    csv_delimiter varchar(3) NOT NULL DEFAULT ','::varchar CHECK (trim(csv_delimiter) <> ''),
    null_value varchar(4) NOT NULL DEFAULT ''::varchar,
    licence_link varchar,
    license_summary text NOT NULL DEFAULT 'internal' CHECK (trim(license_summary) <> ''),
    maintainer_user varchar NOT NULL default SESSION_USER CHECK (trim(maintainer_user) <> ''),
    maintainer_role varchar NOT NULL default CURRENT_ROLE CHECK (trim(maintainer_role) <> '')
);
ALTER TABLE pgingest.import_source ENABLE ROW LEVEL SECURITY;
--CREATE POLICY import_source_policy ON pgingest.import_source USING (maintainer_role = ANY (select UNNEST(current_u) FROM pgingest.my_roles));
CREATE POLICY import_source_policy ON pgingest.import_source USING (maintainer_role = ANY ((select roles FROM pgingest.current_roles cr)::varchar[]));
GRANT ALL ON TABLE pgingest.import_source, pgingest.table_router, pgingest.column_router, pgingest.task_board TO ingest_maintainer;
GRANT SELECT ON TABLE pgingest.import_source, pgingest.table_router, pgingest.column_router, pgingest.task_board TO ingest_auditor;

CREATE TABLE pgingest.task_board (
    task_id serial PRIMARY KEY,
    status varchar,
    import_name varchar REFERENCES pgingest.import_source(import_name),
    start_time timestamp NOT NULL DEFAULT now(),
    maintainer_user varchar NOT NULL default SESSION_USER CHECK (trim(maintainer_user) <> ''),
    maintainer_role varchar NOT NULL default CURRENT_ROLE CHECK (trim(maintainer_role) <> '')
);
ALTER TABLE pgingest.task_board ENABLE ROW LEVEL SECURITY;
CREATE POLICY task_board_policy ON pgingest.task_board USING (maintainer_role = ANY ((select roles FROM pgingest.current_roles cr)::varchar[]));
                                                                                     
CREATE TABLE pgingest.rgx_lib (
    rgx_check_name varchar PRIMARY KEY,
    check_expression varchar,
    description varchar,
    common_data_type varchar,
    valid_example varchar
);

CREATE TABLE pgingest.table_router (
    import_name varchar NOT NULL REFERENCES pgingest.import_source(import_name),
    target_table varchar PRIMARY KEY,
    routing_key varchar,
    routing_key_path varchar,
    routing_key_from int2 NOT NULL DEFAULT 1 CHECK (routing_key_from > 0),
    routing_key_length int2 NULL CHECK (routing_key_length > 0)
);
ALTER TABLE pgingest.table_router ENABLE ROW LEVEL SECURITY;
CREATE POLICY table_router_policy ON pgingest.table_router USING (
    (select maintainer_role from pgingest.import_source ims where ims.import_name=import_name) = ANY ((select roles FROM pgingest.current_roles cr)::varchar[])
); 


CREATE TABLE pgingest.column_router (
    import_name varchar NOT NULL REFERENCES pgingest.import_source(import_name) ON UPDATE CASCADE,
    target_table varchar NOT NULL REFERENCES pgingest.table_router(target_table) ON UPDATE CASCADE,
    value_path varchar NOT NULL DEFAULT 'c0' CHECK (trim(value_path) <> ''),
    value_from int2 NOT NULL DEFAULT 1 CHECK (value_from > 0),
    value_length int2 CHECK (value_length > 0),
    null_value varchar NOT NULL DEFAULT ''::varchar,
    target_column varchar NOT NULL  CHECK (trim(target_column) <> ''),
    target_type varchar NOT NULL DEFAULT 'varchar' CHECK (trim(target_type) <> ''),
    rgx_check_name varchar REFERENCES pgingest.rgx_lib(rgx_check_name),
    lookup_table varchar,
    lookup_column varchar CHECK (trim(lookup_column) <> ''),
    lookup_filter varchar,
    row_filter varchar,
    column_order int4 DEFAULT -1,
    CONSTRAINT column_router_pkey PRIMARY KEY (target_table, target_column)
);
ALTER TABLE pgingest.column_router ENABLE ROW LEVEL SECURITY;
CREATE POLICY column_router_policy ON pgingest.column_router USING (
    (select maintainer_role from pgingest.import_source ims where ims.import_name=import_name) = ANY (
        (select roles FROM pgingest.current_roles cr)::varchar[])
); 


CREATE TABLE pgingest.host_pwd (
    import_name varchar PRIMARY KEY REFERENCES pgingest.import_source(import_name),
    db_role varchar,
    db_pwd varchar
);
ALTER TABLE pgingest.host_pwd ENABLE ROW LEVEL SECURITY;
CREATE POLICY host_pwd_policy ON pgingest.host_pwd  USING ((select maintainer_role from pgingest.import_source ims where ims.import_name=import_name) = ANY (
    (select roles FROM pgingest.current_roles cr)::varchar[])
);
GRANT SELECT(import_name, db_role), INSERT(import_name,db_role, db_pwd), update(import_name,db_role, db_pwd) ON pgingest.host_pwd TO pgingest_maintainer;
GRANT SELECT(import_name, db_role) ON pgingest.host_pwd TO pgingest_auditor;

CREATE TABLE pgingest.target_code (
    priority int PRIMARY KEY,
    description varchar,
    code varchar
);

INSERT INTO pgingest.target_code (priority, description, code) VALUES
(2,'sql code per step and task', 'CREATE TABLE IF NOT EXISTS pgingest.task(task_id int, import_name varchar, step varchar, target varchar, code varchar, completed boolean default false);'),
(3, 'list of error_report MVs', 'CREATE TABLE IF NOT EXISTS pgingest.error_reports(task_id int, import_name varchar, target varchar, report_path varchar);'),
(4, 'list of intermediate tables','CREATE TABLE IF NOT EXISTS pgingest.task_tables(task_id int, import_name varchar, target varchar, table_path varchar);'),
(5, 'procedure to execute task steps', 'CREATE OR REPLACE PROCEDURE pgingest.runner(task_id int, step varchar, target varchar default ''%'')
LANGUAGE plpgsql
as $$ BEGIN
EXECUTE (SELECT string_agg(runner_code, chr(10)) from pgingest.task 
where not completed and task.task_id=runner.task_id and task.step=runner.step and task.target like runner.target);
UPDATE pgingest.task SET completed=TRUE 
WHERE not completed and task.task_id=runner.task_id and task.step=runner.step and task.target like runner.target;
END $$;'),
(6,'overloaded report refresher for task or import_name', 'CREATE OR REPLACE PROCEDURE pgingest.rr(task_id int, target varchar default ''%'')
LANGUAGE plpgsql
as $$ BEGIN
EXECUTE (SELECT string_agg(''REFRESH MATERIALIZED VIEW ''||report_path, chr(10)) from pgingest.error_reports WHERE task.task_id=rr.task_id and task.target like rr.target);
END $$;
CREATE OR REPLACE PROCEDURE pgingest.rr(import_name varchar, target varchar default ''%'')
LANGUAGE plpgsql
as $$ BEGIN
EXECUTE (SELECT string_agg(''REFRESH MATERIALIZED VIEW ''||report_path, chr(10)) from pgingest.error_reports WHERE task.import_name=rr.import_name and task.target like rr.target);
END $$;'),
(7, 'overloaded task cleansing', 'CREATE OR REPLACE PROCEDURE pgingest.cleanup(task_id int, target varchar default ''%'')
LANGUAGE plpgsql
as $$ BEGIN
EXECUTE (SELECT ''DROP TABLE ''||string_agg(table_path, chr(10))||'' cascade;'' from pgingest.task_tables 
where task.task_id=runner.task_id and task.target like runner.target);
END $$;
CREATE OR REPLACE PROCEDURE pgingest.cleanup(task_id int)
LANGUAGE plpgsql
as $$ BEGIN
EXECUTE (SELECT ''DROP TABLE ''||string_agg(table_path, chr(10))||'' cascade;'' from pgingest.task_tables where task.task_id=cleanup.task_id);
END $$;
CREATE OR REPLACE PROCEDURE pgingest.cleanup(import_name varchar)
LANGUAGE plpgsql
as $$ BEGIN
EXECUTE (SELECT ''DROP TABLE ''||string_agg(table_path, chr(10))||'' cascade;'' from pgingest.task_tables where task.import_name=cleanup.import_name);
END $$;')

CREATE OR REPLACE VIEW pgingest.code_gen AS
SELECT td.import_name, tb.task_id
, NOT (tb.status::text = 'completed'::text OR tb.status::text ~~ 'error%'::text) OR tb.status IS NULL active_task
--, ''
,'CREATE TABLE '||td.target_table||'_'||tb.task_id||' AS 
SELECT '|| string_agg(
'nullif(trim(substring('||value_path||','|| value_from||coalesce(', '||value_length,'')||')),'''
||COALESCE(dd.null_value, imps.null_value) ||''')::varchar '|| target_column, '
  ,' ORDER BY dd.column_order, dd.target_column)||'
FROM pgingest.'||td.import_name||'_'||tb.task_id || COALESCE('
WHERE trim(substring('||routing_key_path||','||routing_key_from||coalesce(', '||routing_key_length,'')||')) ='''||routing_key|| '''','')||';
' AS imptask_table
,'INSERT INTO pgingest.error_reports VALUES ('||tb.task_id||','''||tb.import_name||''','''||td.target_table||''','''|| td.target_table|| '_'|| tb.task_id|| '_rgx'');
CREATE MATERIALIZED VIEW '||td.target_table||'_'||tb.task_id||'_rgx AS 
SELECT '||
string_agg('array_agg( distinct case when ('|| dd.target_column||' !~ '''||rgx.rgx_expression||''') THEN '||dd.target_column||' END) '||dd.target_column, '
, ' ORDER BY dd.column_order, dd.target_column)|| '
FROM '|| td.target_table|| '_'|| tb.task_id|| ';
'AS rgx_reports
,'INSERT INTO pgingest.error_reports VALUES ('||tb.task_id||','''||tb.import_name||''','''||td.target_table||''','''|| td.target_table|| '_'|| tb.task_id|| '_fk'');
CREATE MATERIALIZED VIEW '||td.target_table||'_fk AS 
SELECT '|| string_agg(
    'array_agg(distinct case when '|| dd.target_column||'::varchar NOT in (select '||dd.lookup_column||'::varchar FROM '||dd.lookup_table||'_'||tb.task_id
    ||COALESCE(' where '|| dd.lookup_filter, '')||')) THEN '||dd.target_column||' END '||dd.target_column, '
, ') || '
FROM '||td.target_table||'_'||tb.task_id||';
' AS fk_reports
, 'INSERT INTO pgingest.task(task_id int, import_name varchar, step varchar, target varchar, code)
VALUES ('||tb.task_id||','''||td.import_name||''', ''recreate_table'', '''|| td.target_table|| ''', 
''DROP TABLE IF EXISTS '||td.target_table||'_old cascade;
ALTER TABLE IF EXISTS '||td.target_table||' RENAME TO '||split_part(td.target_table, '.', 2)||'_old;
CREATE TABLE '||td.target_table||' AS 
select '|| string_agg(dd.target_column||'::'||dd.target_type, '
,' ORDER BY dd.column_order, dd.target_column)||'
FROM '||td.target_table||'_'||tb.task_id||';'');
' AS table_recreator
, 'INSERT INTO pgingest.task(task_id int, import_name varchar, step varchar, target varchar, code)
VALUES ('||tb.task_id||','''||td.import_name||''',''fill_table'', '''||td.target_table||''',
 ''INSERT INTO '||td.target_table||'('||string_agg(dd.target_column, ',' ORDER BY dd.column_order, dd.target_column)||') 
select '||string_agg(concat(dd.target_column, '::', dd.target_type), '
  ,' ORDER BY dd.column_order, dd.target_column)||'
FROM '||td.target_table||'_'||tb.task_id||';'');
' AS table_filler
, 'INSERT INTO pgingest.task(task_id int, import_name varchar, step varchar, target varchar, code)
VALUES ('||tb.task_id||','''||td.import_name||''',''set_fk'', '''||td.target_table||''',
'''||string_agg('ALTER TABLE '||td.target_table||' ADD CONSTRAINT '||td.target_table||'_'||dd.lookup_table||'_'||dd.lookup_column||'_fk
    FOREIGN KEY ('||dd.target_column||') REFERENCES '||dd.lookup_table||'('||dd.lookup_column||')', ';')
|| ';'');
' AS fk_setter
   FROM  pgingest.pgingest.column_router dd
     JOIN pgingest.pgingest.table_router td USING (import_name, target_table)
     JOIN pgingest.pgingest.task_board tb USING (import_name)
     JOIN pgingest.pgingest.import_source imps USING (import_name)
     JOIN pgingest.pgingest.rgx_lib rgx using(rgx_check_name)
  GROUP BY td.import_name, td.target_table, td.routing_key_from, td.routing_key_length, td.routing_key_path, td.routing_key, tb.task_id;

CREATE OR REPLACE FUNCTION pgingest.task_vars(import_name varchar, OUT varchar)
AS $$
SELECT concat_ws(';'||chr(10)||chr(10)
, 'debugmode="'||debugmode||'"'
, 'source_encoding="'||source_encoding||'"'
, 'csv_delimiter="'||REPLACE(csv_delimiter,'"','\"')||'"'
, 'tg_conn="user='''||host_pwd.db_role||''' password='''||host_pwd.db_pwd||''' host='''||imps.target_host||''' port='''||imps.target_port||''' dbname='''||imps.target_database||'''"'
, 'has_headers='||has_headers
, 'download_link="'||download_link||'"'
, 'pre_import_steps="'||replace(pre_import_steps,'"','\"')||'
dos2unix raw_import
"'
)
FROM pgingest.pgingest.import_source imps
LEFT JOIN pgingest.pgingest.host_pwd USING (import_name)
where imps.import_name=$1;
$$ LANGUAGE sql;
SELECT pgingest.task_vars('gv100');

DROP FUNCTION pgingest.prep_code;
CREATE OR REPLACE FUNCTION pgingest.prep_code(import_name varchar) RETURNS TABLE(code varchar)
AS $$
SELECT 'CREATE SCHEMA IF NOT EXISTS '|| unnest(array_agg(DISTINCT split_part(target_table, '.', 1)::varchar)||'pgingest'::varchar)|| ';'
FROM pgingest.table_router  WHERE target_table::text ~ '.' AND prep_code.import_name=table_router.import_name
UNION ALL (SELECT code FROM pgingest.target_code ORDER BY priority)
$$ LANGUAGE sql;
SELECT pgingest.prep_code('gv100');

CREATE OR REPLACE FUNCTION pgingest.new_task(import_name varchar, OUT int)
AS $$
INSERT INTO pgingest.task_board(import_name) VALUES ($1) RETURNING task_id;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION pgingest.update_task(task_id int, INOUT status varchar)
AS $$
UPDATE pgingest.task_board SET status=$2 WHERE task_id=$1 RETURNING status;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION pgingest.task_code(task_id int, OUT varchar)
AS $$
SELECT concat_ws(chr(10)
,string_agg(imptask_table,chr(10))
,string_agg(rgx_reports,chr(10))
,string_agg(fk_reports,chr(10))
,string_agg(table_recreator,chr(10))
,string_agg(table_filler,chr(10))
,string_agg(fk_setter,chr(10))
)
FROM pgingest.code_gen WHERE task_id=$1;
$$ LANGUAGE sql;

GRANT SELECT ON pgingest.session_roles, pgingest.current_roles TO public; -- define proper privs
