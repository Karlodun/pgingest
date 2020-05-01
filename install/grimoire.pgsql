-- I love funky but descriptive names.... we need more of this here!
-- We go beyond simple automatisation, we want everything to happen automagically (nobody should need to understand the internals of this tool):
-- https://www.urbandictionary.com/define.php?term=automagically
-- dbo names and suggestions are inspired by it.

-- let's create appropriate schema
CREATE SCHEMA grimoire;

-- the main role should sound very superior and magic xD but it cannot be defined here....
CREATE ROLE ingest_maintainer; -- funky name suggestion: ingest_wizard / ingest_sorcerer;
CREATE ROLE ingest_auditor; -- funky name suggestion: overseer?;

 -- maintainers should be able to create roles to manage sources together.
 -- Since PG shares roles among DBs in one DBMS, putting pg_ingest among other dbms could ease the management, especially if data maintainers are already members of specific roles.
 -- the access to configuration tables should be limited based on role membership :-)
GRANT CREATE ROLE TO ingest_maintainer;

GRANT SELECT(import_name, db_role), INSERT(import_name,db_role, db_pwd), update(import_name,db_role, db_pwd) ON host_pwd TO ingest_maintainer;

-- now we create two views which concatenate all accessible roles by session or current user into arrays.
-- this will allow to limit access to import sources by role and help the gui to switch between the roles
CREATE OR REPLACE VIEW grimoire.session_roles
AS WITH RECURSIVE cte AS (
    SELECT pg_roles.oid,    pg_roles.rolname    FROM pg_roles WHERE pg_roles.rolname = SESSION_USER
    UNION
    SELECT m.roleid,        pgr.rolname         FROM cte cte_1
        JOIN pg_auth_members m ON m.member = cte_1.oid
        JOIN pg_roles pgr ON pgr.oid = m.roleid
        )
 SELECT array_agg(cte.rolname) AS session_roles
   FROM cte
  WHERE NOT (cte.rolname ~~ 'pg_%'::text OR cte.rolname ~~ 'rds_%'::text OR cte.rolname = 'postgres'::name);

CREATE OR REPLACE VIEW grimoire.current_roles
AS WITH RECURSIVE cte AS (
    SELECT pg_roles.oid,    pg_roles.rolname    FROM pg_roles WHERE pg_roles.rolname = CURRENT_USER
    UNION
    SELECT m.roleid,        pgr.rolname         FROM cte cte_1
        JOIN pg_auth_members m ON m.member = cte_1.oid
        JOIN pg_roles pgr ON pgr.oid = m.roleid
        )
SELECT array_agg(cte.rolname) AS current_roles
FROM cte
WHERE NOT (cte.rolname ~~ 'pg_%'::text OR cte.rolname ~~ 'rds_%'::text OR cte.rolname = 'postgres'::name);

-- go on with tables.psql
-- then views.psql
-- then permissions.psql