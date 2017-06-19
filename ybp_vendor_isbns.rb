load '../postgres_connect/connect.rb'

c = Connect.new
c.make_query('ybp_vendor_isbns.sql')
c.write_results(YBP_VENDOR_PATH, include_headers: false)
