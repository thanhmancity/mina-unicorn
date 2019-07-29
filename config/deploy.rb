require 'mina/rails'
require 'mina/git'
require 'mina/rvm'
require 'mina/unicorn'
require 'mina/rbenv'  # for rbenv support. (http://rbenv.org)

set :domain, '123.31.47.20'
set :application_name, 'mina-unicorn'


#Set the folder of the remote server where Mina will deploy your application.
set :deploy_to, '/usr/local/mina-unicorn'
set :use_sudo, true
set :app_path, lambda { "#{deploy_to}/#{current_path}" }

#Set a link to the repository. Example: git@bitbucket.pixelpoint/myapp.git
set :repository, 'git@github.com:thanhmancity/mina-unicorn.git'

#Set the name of a branch you plan to deploy as default master.
set :branch, 'master'

set :shared_dirs, fetch(:shared_dirs, []).push('log', 'tmp/pids', 'tmp/sockets', 'public/uploads')
set :shared_files, fetch(:shared_files, []).push('config/database.yml', 'config/secrets.yml', 'config/puma.rb')

#Username of ssh user for access to the remote server.
set :user, 'deploy'

#This is not a required field. You can use it to set an application name for easy recognition.

set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle
  public/system public/uploads}

set :bundle_without, %w{development test}.join(' ') 
# Default value for keep_releases is 5
set :keep_releases, 3

set :delayed_job_server_role, :worker
set :delayed_job_args, "-n 2"


#Set ruby version. If you have RVM installed globally, you’ll also need to set an RVM path, 
#like: set :rvm_use_path, '/usr/local/rvm/scripts/rvm'.
#You can find the RVM location with the rvm info command.
#=====>>> TO VIEW VERSION RUBY: RUN rmv list
task :remote_environment do
  invoke :'rvm:use', 'ruby-2.5.5'
end

task :setup do
  command %[touch "#{fetch(:shared_path)}/config/database.yml"]
  command %[touch "#{fetch(:shared_path)}/config/secrets.yml"]
  command %[touch "#{fetch(:shared_path)}/config/puma.rb"]
  comment "Be sure to edit '#{fetch(:shared_path)}/config/database.yml', 'secrets.yml' and puma.rb."
end

task :deploy do
  deploy do
    comment "Deploying #{fetch(:application_name)} to #{fetch(:domain)}:#{fetch(:deploy_to)}"
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    # invoke :'rvm:load_env_vars'gst
    invoke :'bundle:install'
    invoke :'rails:db_migrate'
    command %{#{fetch(:rails)} db:seed}
    invoke :'rails:assets_precompile'
    invoke :'deploy:cleanup'

    on :launch do
      invoke :'unicorn:restart'
    end
  end
end




namespace :unicorn do
  set :unicorn_pid, "/usr/local/mina-unicorn/current/tmp/pids/unicorn.pid"
  set :start_unicorn, %{
    cd /usr/local/mina-unicorn/current
    bundle exec unicorn -c /usr/local/mina-unicorn/current/config/unicorn/production.rb -E production -D
  }

#                                                                    Start task
# ------------------------------------------------------------------------------
  desc "Start unicorn"
  task :start => :environment do
    queue 'echo "-----> Start Unicorn"'
    queue! start_unicorn
  end

#                                                                     Stop task
# ------------------------------------------------------------------------------
  desc "Stop unicorn"
  task :stop do
    queue 'echo "-----> Stop Unicorn"'
    queue! %{
      test -s "#{unicorn_pid}" && kill -QUIT `cat "#{unicorn_pid}"` && echo "Stop Ok" && exit 0
      echo >&2 "Not running"
    }
  end

#                                                                  Restart task
# ------------------------------------------------------------------------------
  desc "Restart unicorn using 'upgrade'"
  task :restart => :environment do
    invoke 'unicorn:stop'
    invoke 'unicorn:start'
  end
end