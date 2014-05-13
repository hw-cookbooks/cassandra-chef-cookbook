#
# Cookbook Name:: cassandra
# Recipe:: datastax
#
# Copyright 2011-2012, Michael S Klishin & Travis CI Development Team
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

# This recipe relies on a PPA package and is Ubuntu/Debian specific. Please
# keep this in mind.

::Chef::Recipe.send(:require, 'uri')

include_recipe "java"

user node.cassandra.user do
  comment "Cassandra Server user"
  home    node.cassandra.installation_dir
  shell   "/bin/bash"
  action  :create
end

group node.cassandra.user do
  (m = []) << node.cassandra.user
  members m
  action :create
end

[node.cassandra.conf_dir, node.cassandra.data_root_dir, node.cassandra.log_dir, node.cassandra.commitlog_dir].each do |dir|
  directory dir do
    owner     node.cassandra.user
    group     node.cassandra.user
    recursive true
    action    :create
  end
end

# collect credentials for downloading enterprise edition, if present
if node['cassandra']['dse']
  dse = node.cassandra.dse
  if dse.credentials.databag
    dse_credentials = Chef::EncryptedDataBagItem.load(dse.credentials.databag.name,dse.credentials.databag.item)[dse.credentials.databag.entry]
  else
    dse_credentials = dse.credentials
  end
end

# generate platform-specific repo URI
repo_host = value_for_platform(['debian','ubuntu'] => {
                                 'default' => 'debian.datastax.com'
                               },
                               [ 'rhel', 'centos', 'amazon' ] => {
                                 'default' => 'rpm.datastax.com'
                               })

# set the repo URI path and credentials, depending on
# the availability of enterprise edition credentials
repo_path = dse_credentials ? '/enterprise' : '/community'

repo_config = { :host => repo_host, :path => repo_path }

if dse_credentials
  repo_user = dse_credentials['username']
  repo_pass = dse_credentials['password']
  repo_config.merge!({ :userinfo => [repo_user, repo_pass].join(':') })
end

repo_uri = URI::HTTPS.build(repo_config)

case node.platform_family
when "debian"
  package "apt-transport-https"

  apt_repository "datastax" do
    uri          repo_uri.to_s
    distribution "stable"
    components   ["main"]
    key          "http://debian.datastax.com/debian/repo_key"
    action       :add
  end

  # DataStax Server Community Edition package will not install w/o this
  # one installed. MK.
  package "python-cql" do
    action :install
    only_if { repo_uri.path == '/community' }
  end

  # This is necessary because apt gets very confused by the fact that the
  # latest package available for cassandra is 2.x while you're trying to
  # install dsc12 which requests 1.2.x.
  if node.platform_family == "debian" then
    package "cassandra" do
      action :install
      version node.cassandra.version
    end
  end

when "rhel"
  include_recipe "yum"

  yum_repository "datastax" do
    description "DataStax Repo for Apache Cassandra"
    baseurl repo_uri.to_s
    gpgcheck false
    action :create
  end

  yum_package "#{node.cassandra.package_name}" do
    version "#{node.cassandra.version}-#{node.cassandra.release}"
    allow_downgrade
  end

end

link '/etc/init.d/cassandra' do
  to '/etc/init.d/dse'
  only_if { ::File.exists?('/etc/init.d/dse') && !::File.exists?('/etc/init.d/cassandra') }
end

%w(cassandra.yaml cassandra-env.sh).each do |f|
  template File.join(node.cassandra.conf_dir, f) do
    cookbook node.cassandra.templates_cookbook
    source "#{f}.erb"
    owner node.cassandra.user
    group node.cassandra.user
    mode  0644
    if ::File.exists?("#{node.cassandra.conf_dir}/first_run_complete.json")
      notifies :restart, "service[cassandra]", :delayed
    end
  end
end

service "cassandra" do
  supports :restart => true, :status => true
  service_name node.cassandra.service_name
  action [:enable, :start]
  only_if { ::File.exists?("#{node.cassandra.conf_dir}/first_run_complete.json") }
end

file "#{node.cassandra.conf_dir}/first_run_complete.json" do
  content "{}"
end
