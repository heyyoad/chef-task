#
# Cookbook Name:: teamcityapp
# Recipe:: default
#
# Copyright 2017, Yoad Fekete
#
# All rights reserved - Do Not Redistribute
#

# gets the attributes from the attribues file

version = node['teamcity']['version']
service_name = node['teamcity']['service-name']
service_username = node['teamcity']['service-username']
service_group = node['teamcity']['service-group']

# GENERAL VARS

src_filename = "TeamCity-#{version}.tar.gz"
src_uri = node['teamcity']['src-uri'] || "http://download.jetbrains.com/teamcity/#{src_filename}"
src_filepath = "#{Chef::Config[:file_cache_path]}/#{src_filename}" 
extract_path = "/opt/TeamCity-#{version}"
data_path = "#{extract_path}/.BuildServer"
bin_path = "#{extract_path}/bin"

# adds the service group

group service_group 

# add the service username and assign it to the service_group

user service_username do
    gid service_group
    shell '/bin/bash'
end

# including dependency recipes

include_recipe "java_se"
include_recipe "postgresql"
include_recipe "sudo"

# Starting download if file doesn't exist

log "downloading teamcity from: srv_uri if it doesn't exist"
remote_file src_filepath do
    source src_uri 
    not_if { ::File.exists?(extract_path) }
end

# Extracting the tar file

bash 'extract' do
    cwd ::File.dirname(src_filepath)
    code <<-EOH
        mkdir -p #{extract_path}
        tar xzf #{src_filename} -C #{extract_path} --strip-components 1
        chown -R #{service_username}.#{service_group}  #{extract_path}
    EOH
#    not_if { ::File.exists?(extract_path) }
end

# Setting correct ownership on the relevant dirs (and creating those if they don't exist)

directory data_path do
    owner service_username
    group service_group
    mode 0755
    recursive true
end

directory "#{data_path}/config" do
    owner service_username
    group service_group
    mode 0755
    recursive true
end

directory "#{data_path}/lib/jdbc" do
    owner service_username
    group service_group
    mode 0755
    recursive true
end


# Copying local databse file with properties for postgres deployment

cookbook_file 'database.properties' do
    path "#{data_path}/config/database.properties"
    owner service_username
    group service_group
    mode 0755
end

# this file will define the data lib path

cookbook_file 'teamcity-startup.properties' do
    path "#{extract_path}/conf/teamcity-startup.properties"
    owner service_username
    group service_group
    mode 0755
end

# copying postgres driver needed for pg database
cookbook_file 'postgresql-42.1.1.jar' do
    path "#{data_path}/lib/jdbc/postgresql-42.1.1.jar"
    owner service_username
    group service_group
    mode 0755
end

# trying environment variable for datapath, just in case :)

ENV['TEAMCITY_DATA_PATH '] = '/opt/TeamCity-2017.1.2/.BuildServer'

# running stop script to kill idle catalina instances

bash 'stopCatalina' do
    user 'teamcity'
    ignore_failure true
    cwd ::File.dirname(bin_path)
    code <<-EOH
    /usr/bin/sudo #{bin_path}/shutdown.sh
    EOH
    only_if { ::File.exists?(bin_path) }
end

# running start script

bash 'runAll' do
    user 'teamcity'
    cwd ::File.dirname(bin_path) 
    code <<-EOH
    /usr/bin/sudo #{bin_path}/runAll.sh start
    EOH
    only_if { ::File.exists?(bin_path) }
end

# Accepting license restfully
bash 'accept license' do
    cwd extract_path
    code <<-EOH
        until curl -v 'http://localhost:8111' 2>&1 | grep -ic 'showAgreement'
        do
            sleep 1
            echo 'waiting for teamcity license agreement to load'
        done
        curl 'http://localhost:8111/showAgreement.html' -H 'Content-Type: application/x-www-form-urlencoded' --data 'accept=true'
        touch license-accepted
    EOH
    not_if { ::File.exists?("#{extract_path}/license-accepted") }
    only_if { node['teamcity']['accept-license'] }
end

# creating admin restfully
bash 'create teamcity admin user' do
    cwd extract_path
    code <<-EOH
        pattern='Super user authentication token: "(.*)"'
        file='logs/teamcity-server.log'
        until grep -iEc "$pattern" "$file"
        do
            sleep 1
            echo "waiting for superuser auth token to be written to $file"
        done
        token=$(grep -ioE "$pattern" "$file" | grep -oE '[0-9]*' | tail -1)
        curl "http://localhost:8111/httpAuth/app/rest/users" --basic -u ":$token" -H "Content-Type: application/json" -d '{"username": "#{node['teamcity']['admin-username']}", "password": "#{node['teamcity']['admin-password']}"}'
        curl "http://localhost:8111/httpAuth/app/rest/users/username:#{node['teamcity']['admin-username']}/roles/SYSTEM_ADMIN/g/" -X PUT --basic -u ":$token" 
        touch admin-user-created
    EOH
    not_if { ::File.exists?("#{extract_path}/admin-user-created") }
end
