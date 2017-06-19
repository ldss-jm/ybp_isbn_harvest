load '../postgres_connect/connect.rb'

c = Connect.new
c.make_query('all_isbns.sql')
if defined?(ALL_ISBNS_PATH)
  c.write_results(ALL_ISBNS_PATH, include_headers: false)
else
  c.write_results('all_isbns_results.txt', include_headers: false)
end