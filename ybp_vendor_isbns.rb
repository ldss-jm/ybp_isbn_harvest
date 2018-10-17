require_relative '../postgres_connect/connect.rb'

c = Connect.new
c.make_query(File.join(__dir__, 'ybp_vendor_isbns.sql'))
c.write_results(YBP_VENDOR_PATH, include_headers: false)
