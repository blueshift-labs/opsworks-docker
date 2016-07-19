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
  container_name  = node[:sidekiq][:container_name]
  config_path     = node[:sidekiq][:config_path]
  sidekiq_tag     = node[:sidekiq][:tag]
  app_shared      = "/srv/www/#{app}/shared"
  log_path        = "#{app_shared}/log/sidekiq.log"
  
  script "docker_clean" do
    interpreter "bash"
    user "root"
    code <<-EOH            
      if docker ps -a | awk '{print $NF}' | grep #{container_name}; 
      then
        docker ps -a | awk '{print $NF}' | grep #{container_name} | xargs docker stop 
        sleep 3
        docker ps -a | awk '{print $NF}' | grep #{container_name} | xargs docker rm -f
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
        exec_cmd="cd #{app_root};bundle exec sidekiq -g #{sidekiq_tag} -C #{config_path}"        
        docker run #{dockerenvs} -d --name #{container_name} --user=#{app_user}  #{registry}/#{repo}:#{repo_tag}  /bin/bash -i -c "$exec_cmd" 
    EOH
  end
end

