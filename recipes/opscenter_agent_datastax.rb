include_recipe "cassandra::_datastax_repo"
include_recipe "java"

server_ip = node[:cassandra][:opscenter][:agent][:server_host]
if !server_ip
  search_results = search(:node, "roles:#{node[:cassandra][:opscenter][:agent][:server_role]}")
  unless search_results.empty?
    server_ip = search_results[0]['ipaddress']
  else
    return # Continue until opscenter will come up
  end
end

package "#{node[:cassandra][:opscenter][:agent][:package_name]}" do
  action :install
end

service "datastax-agent" do
  supports :restart => true, :status => true
  action [:enable, :start]
end


template "/etc/datastax-agent/address.yaml" do
  mode 0644
  source "opscenter-agent.conf.erb"
  variables({
    :server_ip => server_ip
  })
  notifies :restart, "service[datastax-agent]"
end
