$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'fileutils'
require 'set'
require 'mail'

require 'zip'
require 'library_stdnums'
require 'sierra_postgres_utilities'

module YBPHoldingsService
  autoload :Harvest, 'ybp_holdings_service/audit'
  autoload :Harvest, 'ybp_holdings_service/harvest'
  autoload :Institution, 'ybp_holdings_service/institution'
end
