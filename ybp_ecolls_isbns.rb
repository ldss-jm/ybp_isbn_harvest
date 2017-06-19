load '../postgres_connect/connect.rb'

c = Connect.new
c.make_query('ybp_ecolls_isbns.sql')
c.write_results(YBP_ECOLLS_PATH, include_headers: false)
