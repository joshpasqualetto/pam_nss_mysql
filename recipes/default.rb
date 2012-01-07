# Author:: Josh Pasqualetto <josh.pasqualetto@sonian.net>
# Cookbook Name:: pam_nss_mysql
# Recipe:: default
#
# Copyright 2011, Sonian, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
include_recipe "mysql::client"
package "libpam-mysql"
package "libnss-mysql"

gem_package "mysql"

creds = Chef::EncryptedDataBagItem.load("credentials", "generic", databag_key).to_hash

pam_root_db_user = creds['pam_root_db_user']
pam_root_db_passwd = creds['pam_root_db_passwd']
pam_db_user = creds['pam_db_user']
pam_db_passwd = creds['pam_db_passwd']
pam_ro_db_user = creds['pam_ro_db_user']
pam_ro_db_passwd = creds['pam_ro_db_passwd']


# This is here to cleanup this schema file as it has sensitive information in it. not_if block below should stop it from being created if the db && tables exist.
schema_file = file "/tmp/pam-nss-schema.sql" do
  action :nothing
end
schema_file.run_action(:delete)


template node.pam_nss_mysql.sql_schema_file do
  mode "0600"
  owner "root"
  group "root"
  backup false
  variables(:pam_root_db_user => pam_root_db_user,
            :pam_root_db_passwd => pam_root_db_passwd,
            :pam_db_user => pam_db_user,
            :pam_db_passwd => pam_db_passwd,
            :pam_ro_db_user => pam_ro_db_user,
            :pam_ro_db_passwd => pam_ro_db_passwd)
  action :create_if_missing
  not_if do
    if File.exists?(node.pam_nss_mysql.pam.config_file)
      true
    else
      require 'mysql'
      m = Mysql.new(node.pam_nss_mysql.pam.db_host, pam_root_db_user, pam_root_db_passwd)
      if m.list_dbs.include?(node.pam_nss_mysql.pam.database)
        m.select_db(node.pam_nss_mysql.pam.database)
        t = m.list_tables
        if [t.include?(node.pam_nss_mysql.pam.users_table), t.include?(node.pam_nss_mysql.pam.groups_table), t.include?(node.pam_nss_mysql.pam.user_groups_table)].include?(true)
          true
        else
          Chef::Log.info("pam-nss-mysql database: #{node.pam_nss_mysql.pam.database} is present, however tables are not -- populating them.")
          notifies :run, resources(:execute => "create-pam-nss-mysql-tables"), :delayed
          false
        end
      else
        Chef::Log.info("pam-nss-mysql database: #{node.pam_nss_mysql.pam.database} is NOT present, creating it then populating tables.")
        notifies :run, resources(:execute => "create-pam-nss-mysql-database"), :delayed
        notifies :run, resources(:execute => "create-pam-nss-mysql-tables"), :delayed
        false
      end
    end
  end
end

execute "create-pam-nss-mysql-database" do
  command "/usr/bin/mysqladmin -u #{pam_root_db_user} -p#{pam_root_db_passwd} -h #{node.pam_nss_mysql.pam.db_host} create #{node.pam_nss_mysql.pam.database}"
  action :nothing
end

execute "create-pam-nss-mysql-tables" do
  command "/usr/bin/mysql -u #{pam_root_db_user} -p#{pam_root_db_passwd} -h #{node.pam_nss_mysql.pam.db_host} < #{node.pam_nss_mysql.sql_schema_file}"
  action :nothing
end

cookbook_file "/etc/nsswitch.conf" do
  mode "0644"
  owner "root"
  group "root"
end

template "/etc/nss-mysql.conf" do
  mode "0644"
  owner "root"
  group "root"
  variables(:db_host => node.pam_nss_mysql.pam.db_host,
            :database => node.pam_nss_mysql.pam.database,
            :db_user => pam_ro_db_user,
            :db_passwd => pam_ro_db_passwd,
            :users_table => node.pam_nss_mysql.pam.users_table,
            :groups_table => node.pam_nss_mysql.pam.groups_table,
            :user_groups_table => node.pam_nss_mysql.pam.user_groups_table)
end

template "/etc/nss-mysql-root.conf" do
  mode "0600"
  owner "root"
  group "root"
  backup false
  variables(:db_host => node.pam_nss_mysql.pam.db_host,
            :database => node.pam_nss_mysql.pam.database,
            :db_user => pam_db_user,
            :db_passwd => pam_db_passwd,
            :users_table => node.pam_nss_mysql.pam.users_table)
end

template node.pam_nss_mysql.pam_ro.config_file do
  source "pam-mysql.conf.erb"
  mode "0644"
  owner "root"
  group "root"
  variables(:db_host => node.pam_nss_mysql.pam.db_host,
            :database => node.pam_nss_mysql.pam.database,
            :db_user => pam_ro_db_user,
            :db_passwd => pam_ro_db_passwd,
            :users_table => node.pam_nss_mysql.pam.users_table,
            :encryption_type => node.pam_nss_mysql.encryption_type,
            :verbose => node.pam_nss_mysql.debug.verbose,
            :sql_logging => node.pam_nss_mysql.debug.sql_logging,
            :debug_log_table => node.pam_nss_mysql.debug.log_table)
end

template node.pam_nss_mysql.pam.config_file do
  source "pam-mysql.conf.erb"
  mode "0600"
  owner "root"
  group "root"
  backup false
  variables(:db_host => node.pam_nss_mysql.pam.db_host,
            :database => node.pam_nss_mysql.pam.database,
            :db_user => pam_db_user,
            :db_passwd => pam_db_passwd,
            :users_table => node.pam_nss_mysql.pam.users_table,
            :encryption_type => node.pam_nss_mysql.encryption_type,
            :verbose => node.pam_nss_mysql.debug.verbose,
            :sql_logging => node.pam_nss_mysql.debug.sql_logging,
            :debug_log_table => node.pam_nss_mysql.debug.log_table)
end

template "/etc/pam.d/common-auth" do
  mode "0600"
  owner "root"
  group "root"
  variables(:config_file => node.pam_nss_mysql.pam.config_file)
end

template "/etc/pam.d/common-account" do
  mode "0600"
  owner "root"
  group "root"
  variables(:config_file => node.pam_nss_mysql.pam_ro.config_file)
end

template "/etc/pam.d/common-session" do
  mode "0600"
  owner "root"
  group "root"
  variables(:config_file => node.pam_nss_mysql.pam_ro.config_file)
end

template "/etc/pam.d/common-password" do
  mode "0600"
  owner "root"
  group "root"
  variables(:config_file => node.pam_nss_mysql.pam.config_file)
end
