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

  app                   = node[:app][:name]
  app_root              = node[:app][:root]
  app_user              = node[:app][:user]
  repo                  = node[:app][:repo]
  repo_tag              = node[:app][:repo_tag]
  registry              = node[:docker][:insecure_registry]
  container_name        = node[:sidekiq][:container_name]
  config_path           = node[:sidekiq][:config_path]
  sidekiq_tag           = node[:sidekiq][:tag]
  queue_scale_up        = node[:sidekiq][:queue_scale_up]
  queue_scale_down      = node[:sidekiq][:queue_scale_down]
  dd_api_key            = node[:datadog][:api_key]
  dd_app_key            = node[:datadog][:application_key]
  app_shared            = "/srv/www/#{app}/shared"
  log_path              = "#{app_shared}/log/sidekiq.log" 

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

  template "/srv/www/#{app}/current/sidekiq_utils.sh" do
    source "sidekiq_utils.erb"
    owner "root"
    group "root"
    mode "0755"
    variables(
      :app => app,
      :app_root => app_root,
      :app_user => app_user,
      :repo => repo,
      :repo_tag => repo_tag,
      :registry => registry,
      :container_name => container_name,
      :config_path => config_path,
      :sidekiq_tag => sidekiq_tag,
      :dd_api_key => dd_api_key,
      :dd_app_key => dd_app_key,
      :app_shared => app_shared,
      :log_path => log_path,
      :dockerenvs => dockerenvs,
      :queue_scale_up => queue_scale_up,
      :queue_scale_down => queue_scale_down
    )
  end

  script "sidekiq_exclusive" do
    interpreter "bash"
    user "root"
    code <<-EOH
        cd #{app_root}
        queue_list=`cat /srv/www/#{app}/current/config/sidekiq.yml  | grep -A 100 'queues' | awk 'NR>1{print $2}'`
        for queue in ${queue_list[@]};do
            crontab -l | { cat; echo "*/3 * * * * cd /srv/www/#{app}/current && ./sidekiq_utils.sh $queue"; } | crontab -
        done
    EOH
  end
end

