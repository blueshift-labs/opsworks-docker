case node[:platform]
when "ubuntu","debian"
  package "docker.io" do
    action :install
  end
when 'centos','redhat','fedora','amazon'
  package "docker" do
    action :install
  end
end

template '/etc/default/docker' do
  source 'docker.erb'
end

service "docker" do
	action :restart
end