include_recipe "cassandra::_datastax_repo"
include_recipe "java"

package "#{node[:cassandra][:opscenter][:server][:package_name]}" do
  action :install
end

# Fix for no /etc/redhat-release on Amazon Linux, see here:
# http://www.datastax.com/support-forums/topic/opscenter-installs-but-i-keep-getting-exceptionsimporterror-no-module-named-thriftthrift
if node[:platform] == 'amazon'
  cookbook_file '/usr/share/opscenter/bin/opscenter' do
    source 'opscenter'
    owner 'root'
    group 'root'
    mode 0755
    action :create
  end
end

service "opscenterd" do
  supports :restart => true, :status => true
  action [:enable, :start]
end

template "/etc/opscenter/opscenterd.conf" do
  source "opscenterd.conf.erb"
  mode 0644
  notifies :restart, resources(:service => "opscenterd"), :delayed
end

