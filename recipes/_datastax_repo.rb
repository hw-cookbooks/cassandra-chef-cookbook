::Chef::Recipe.send(:require, 'uri')

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
repo_host = value_for_platform(
              ['debian','ubuntu'] => {
                'default' => 'debian.datastax.com'
              },
              [ 'rhel', 'centos', 'amazon' ] => {
                'default' => 'rpm.datastax.com'
              }
)

# set the repo URI path and credentials, depending on
# the availability of enterprise edition credentials
repo_path = dse_credentials ? '/enterprise' : '/community'

repo_config = { :host => repo_host, :path => repo_path }

if dse_credentials
  repo_user = dse_credentials['username']
  repo_pass = dse_credentials['password']
  repo_config.merge!({ :userinfo => [repo_user, repo_pass].join(':') })
end

node.set[:cassandra][:datastax_repo_uri] = URI::HTTPS.build(repo_config).to_s

case node.platform_family
when "debian"
  package "apt-transport-https"

  apt_repository "datastax" do
    uri          node[:cassandra][:datastax_repo_uri]
    distribution "stable"
    components   ["main"]
    key          "http://debian.datastax.com/debian/repo_key"
    action       :add
  end

when "rhel"
  include_recipe "yum"

  yum_repository "datastax" do
    description "DataStax Repo for Apache Cassandra"
    baseurl node[:cassandra][:datastax_repo_uri]
    gpgcheck false
    action :create
  end

end
