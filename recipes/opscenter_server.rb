include_recipe "cassandra::_datastax_repo"
include_recipe "java"

package "#{node[:cassandra][:opscenter][:server][:package_name]}" do
  action :install
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

