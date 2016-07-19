include_recipe 'deploy'

node[:deploy].each do |application, deploy|
  
  opsworks_deploy_dir do
    user deploy[:user]
    group deploy[:group]
    path deploy[:deploy_to]
  end

  opsworks_deploy do
    deploy_data deploy
    app application
  end

  app             = node[:app][:name]
  app_root        = node[:app][:root]
  app_user        = node[:app][:user]
  repo            = node[:app][:repo]
  repo_tag        = node[:app][:repo_tag]
  registry        = node[:docker][:insecure_registry]
  container_name  = node[:puma][:container_name]
  config_path     = node[:puma][:config_path]
  app_shared      = "/srv/www/#{app}/shared"

  script "docker_clean" do
    interpreter "bash"
    user "root"
    code <<-EOH            
      if docker ps -a | awk '{print $NF}' | grep #{container_name}; 
      then
        docker stop #{container_name}
        sleep 3
        docker rm #{container_name}
        sleep 3
      fi             
    EOH
  end 

  script "docker-pull" do
    interpreter "bash"
    user "root"
    code <<-EOH
        docker pull #{registry}/#{repo}:#{repo_tag}
    EOH
  end
  
  dockerenvs = " "
  deploy[:environment_variables].each do |key, value|
    dockerenvs=dockerenvs+" -e "+key+"="+value
  end

  script "docker-run" do
    interpreter "bash"
    user "root"
    code <<-EOH
        exec_cmd="cd #{app_root};bundle exec puma -C #{config_path}"        
        docker run #{dockerenvs} -d --name #{container_name} --user=#{app_user} -p 80:9100  #{registry}/#{repo}:#{repo_tag}  /bin/bash -i -c "$exec_cmd"
    EOH
  end
end

