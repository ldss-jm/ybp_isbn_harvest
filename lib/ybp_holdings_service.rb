$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'fileutils'
require 'set'

require 'zip'
require 'library_stdnums'

module YBPHoldingsService
  autoload :Harvest, 'ybp_holdings_service/harvest'
  autoload :ISBN, 'ybp_holdings_service/harvest'
  autoload :Institution, 'ybp_holdings_service/institution'
end
