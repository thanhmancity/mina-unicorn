# lib/tasks/deploy.rake
namespace :deploy do
    desc 'Deploy to staging environment'
    task :staging do
      exec 'mina deploy -f config/deploy/staging.rb'
    end
  end