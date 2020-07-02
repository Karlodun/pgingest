# pgingest
Since PG shares roles among DBs in one DBMS, putting pg_ingest among other dbms could ease the management, especially if data maintainers are already members of specific roles in other DBs.
This will allow to limit access to import sources by role and help the gui to switch between the roles

Newest but yet untested code (bugs and minor issues may be there)

# Setup instructions
#create user with appropriate group and home directory, I'd suggest following code:
  useradd -G wwwrun -d /srv/pgingest pgingest # home directory in srv, should be configured to v-host in apache
  cd /srv/
#clone repo and change owner
  git clone https://github.com/Karlodun/pgingest/
  sudo chown -R pgingest:wwwrun pgingest/
#switch to pgingest user, enter home directory and create missing directories
sudo su pgingest
cd ~
mkdir logs tmp uploads
#set appropriate rights
chmod -R +r /srv/pgingest/*
chmod -R -r+x /srv/pgingest/bin

#execute in target postgresql database:
CREATE USER pgingest WITH login PASSWORD '<password>'; -- should be passwordless if localhost
CREATE SCHEMA AUTHORIZATION pgingest;
ALTER DEFAULT PRIVILEGES IN SCHEMA pgingest GRANT ALL ON TABLES TO pgingest;

CREATE ROLE pgingest_maintainer;
CREATE ROLE pgingest_auditor;
GRANT pgingest_maintainer, pgingest_auditor TO pgingest;

#configure credentials in pgingest/.pg_service.conf
#run db install script:
psql service=pgingest -f install.sql

# Big TODOs:
* Improve WUI
** add import management (today only via SQL client)
** add import task management
** develop appropriate style
* Improve security (setup v-host, finalize db security policies and other settings, apply appropriate chmod)
* Automate install (contemporary the install script is not working) and provide a way to create config details for DBMS connection
* Provide a good list for common regular expressions, and extend existing framework in a way, that those can be selected (either written rgx, or selected from rgx table). And the install script should import those.
