# pg_ingest

Newest but yet untested code (bugs and minor issues may be there)

Big TODOs:
* Improve WUI
* Improve security (setup v-host, finalize db security policies and other settings, apply appropriate chmod)
* Automate install (contemporary the install script is not working) and provide a way to create config details for DBMS connection
* Provide a good list for common regular expressions, and extend existing framework in a way, that those can be selected (either written rgx, or selected from rgx table). And the install script should import those.
* Extend with select statement creator view, which should handle labels.
** labels should be included into table and column (data) definitions. Those should be JSON with {lang:value} format. (selfnote: rename data_definitions into column definitions?)
** another view must be created, which shows simple select statements - should ease the use of external tools
just imagine, you could fetch this code with a reporting tool and copy-paste it :-)
