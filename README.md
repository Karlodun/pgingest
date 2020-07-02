# pgingest
Since PG shares roles among DBs in one DBMS, putting pg_ingest among other dbms could ease the management, especially if data maintainers are already members of specific roles in other DBs.
This will allow to limit access to import sources by role and help the gui to switch between the roles

Newest but yet untested code (bugs and minor issues may be there)

Big TODOs:
* Improve WUI
** add import management (today only via SQL client)
** add import task management
** develop appropriate style
* Improve security (setup v-host, finalize db security policies and other settings, apply appropriate chmod)
* Automate install (contemporary the install script is not working) and provide a way to create config details for DBMS connection
* Provide a good list for common regular expressions, and extend existing framework in a way, that those can be selected (either written rgx, or selected from rgx table). And the install script should import those.
