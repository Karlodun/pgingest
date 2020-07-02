# pgingest
 was developed as a small "ETL" alike tool, for non-technicians to aid in repetitive ingestion of external into a PostgreSQL database.
# Features
Data sources and targets
 Multiple import tasks on same source possible
 Download data from external sources via CURL
 Upload data via Web GUI
 Ingest each source into dedicated host, database and schema
Easy configuration
	Configuration via several tables
Automatic creation of target schemas, tables and backups
Routing of data
Can recreate tables or append data
into different tables based on column values
	Extracting of substrings, including fixed length sources
 	Extracting of data via path, including JSON path and functions
Error reports based on regular expressions and comparisons with lookup data
Data type conversions

# Installing pgingest on a server with other DBMS
Since PG shares roles among DBs in one DBMS, putting pg_ingest among other dbms could ease the management, especially if data maintainers are already members of specific roles in other DBs.
This will allow to limit access to import sources by role and help the gui to switch between the roles

Newest but yet untested code (bugs and minor issues may be there)

# Setup instructions
create user with appropriate group and home directory, I'd suggest following code:
``` bash
useradd -G wwwrun -d /srv/pgingest pgingest # home directory in srv, should be configured to v-host in apache
cd /srv/
```
clone repo and change owner
``` bash
git clone https://github.com/Karlodun/pgingest/
sudo chown -R pgingest:wwwrun pgingest/
```
switch to pgingest user, enter home directory and create missing directories
``` bash
sudo su pgingest
cd ~
mkdir logs tmp uploads
#set appropriate rights
chmod -R +r /srv/pgingest/*
chmod -R -r+x /srv/pgingest/bin
```
execute in target postgresql database:
``` sql
CREATE USER pgingest WITH login PASSWORD '<password>'; -- should be passwordless if localhost
CREATE SCHEMA AUTHORIZATION pgingest;
ALTER DEFAULT PRIVILEGES IN SCHEMA pgingest GRANT ALL ON TABLES TO pgingest;

CREATE ROLE pgingest_maintainer;
CREATE ROLE pgingest_auditor;
GRANT pgingest_maintainer, pgingest_auditor TO pgingest;
```
configure credentials in pgingest/.pg_service.conf
run db install script:
``` bash
psql service=pgingest -f install.sql
```

# Setup a php enabled webserver for GUI (if required)
TODO

# Usage
You start your journey with import_source, continue to table_router then column_router and finally define the host_pwd.
Additionally you can add your entries into rgx_lib
