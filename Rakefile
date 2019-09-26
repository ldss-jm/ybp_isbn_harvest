require 'rspec/core/rake_task'
require 'rake/clean'
require_relative 'lib/ybp_holdings_service'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

desc 'Harvest ISBNs to send to YBP as adds/deletes'
task :harvest do
  YBPHoldingsService::Harvest.new.execute
end

desc 'Harvest ISBNs USING EXISTING QUERY DATA'
task :queryless_harvest do
  YBPHoldingsService::Harvest.new(use_existing_query_data: true).execute
end

desc 'Run a full/new harvest; presumes YBP Holdings data is empty'
task :new_harvest do
  YBPHoldingsService::Harvest.new(new_harvest: true).execute
end

desc 'Noty implemented - Compare YBP ISBN holdings to our own to find adds/deletes'
task :audit do
  # todo
end
