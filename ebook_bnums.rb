load '../postgres_connect/connect.rb'

c = Connect.new
c.make_query('ebook_bnums.sql')
c.write_results(EBOOK_BNUMS_PATH, include_headers: false)