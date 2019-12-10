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

desc 'Compare YBP ISBN holdings to our own to find adds/deletes'
task :audit do
  sh 'sort data/comprehensive.txt > data/comp_srt.audit'
  sh 'grep "|\\(EBOOK\\|UNC\\)_LOAD|" data/holdings.txt | sort > data/ybp_srt.audit'
  sh 'comm -13 data/comp_srt.audit data/ybp_srt.audit > data/UNC-3030_DELETES_audit_holdings_load.txt'
  sh 'comm -23 data/comp_srt.audit data/ybp_srt.audit > data/UNC-3030_ADDS_audit_holdings_load.txt'
  sh 'rm data/*.audit'
end
