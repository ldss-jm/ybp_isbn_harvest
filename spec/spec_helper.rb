$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

ENV['SIERRA_DELAY_CONNECT'] = '1'

require 'bundler/setup'
require 'ybp_holdings_service'
