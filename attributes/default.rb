# This pam logging table is created ONLY if this is set true on the initial run, if you change this to false and want to change this to true later review the schema file and create the table.
# Then change this back to true.
default.pam_nss_mysql.debug.sql_logging = true
default.pam_nss_mysql.debug.log_table = "pam_mysql_logs"
# Sets verbose logging inside of the auth.log, set to true for debugging purposes, I would leave it off in production however for security reasons.
default.pam_nss_mysql.debug.verbose = false

# root-only accessable file, RW access to SQL tables, will be created during schema loading via recipe.
default.pam_nss_mysql.pam.config_file = "/etc/pam-mysql.conf"
default.pam_nss_mysql.pam.db_host = "localhost"
default.pam_nss_mysql.pam.database = "security"
default.pam_nss_mysql.pam.users_table = "system_users"
default.pam_nss_mysql.pam.groups_table = "system_groups"
default.pam_nss_mysql.pam.user_groups_table = "system_user_groups"

# System accessable read-only file, Read only access to SQL, will be created during schema loading via recipe.
default.pam_nss_mysql.pam_ro.config_file = "/etc/pam-mysql-ro.conf"

# 0 = no encryption, 1 = crypt() passwords (system), 2 = mysql PASSWORD()'s, 3 = plain hex md5, 4 = plain hex SHAA
default.pam_nss_mysql.encryption_type = 3

# Where schema file is stored if db/tables are not present
default.pam_nss_mysql.sql_schema_file = "/tmp/pam-nss-schema.sql"
