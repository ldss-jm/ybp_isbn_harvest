require 'library_stdnums'

# holdings.txt is a report ybp can generate for us listing all
# of our holdings load data (including data loaded by ybp, outside
# of these loads we're doing). In requesting reports like this, there may
# have been some confusion about what we were asking for or whether
# it was possible. It's probably best to make new requests for the report
# using the email thread from the previous successful request.

# ybp holdings are all ISBN-13s (ISBN-10s we send them are converted
# to ISBN-13s)

# We want to:
#   find isbns that should be in our ybp holdings but aren't --
#     if unc_isbn not in ybp_list && unc_isbn.to_13 not in ybp_list
#   find isbns that are in our ybp holdings and shouldn't be
#     if ybp_isbn not in unc_list && ybp_isbn.to_10 not in unc_list

# YBP also rejects invalid isbns, so when we find isbns that ought to be
# in our ybp holdings, we remove any invalid isbns.

# The output of this script is used to grep the unc/ybp holdings to
# identify lines that need to be added/removed from ybp holdings


# get a sorted list of ybp holdings isbns
ybp = File.readlines('data/holdings.txt')
ybp.shift
ybp = ybp.reject { |line| line !~ /(unc|ebook)_load/i }.
          map! { |line| line.split("|").first }.
          sort!

# get a sorted list of unc holdings isbns
unc = File.readlines('data/comprehensive.txt')
unc.map! { |x| x.split("|").first }.sort!

def item_in_list?(item, lst)
  lst.bsearch { |x| item <=> x }
end

adds = []
good = []
unc.each do |isbn|
  if item_in_list?(isbn, ybp)
    good << isbn
  elsif item_in_list?(StdNum::ISBN.convert_to_13(isbn), ybp)
    good << isbn
  else
    adds << isbn
  end
end

ygood = [] # properly reflected in unc holdings
dels = []
ybp.each do |isbn|
  if item_in_list?(isbn, unc)
    ygood << isbn
  elsif item_in_list?(StdNum::ISBN.convert_to_10(isbn), unc)
    ygood << isbn
  else
    dels << isbn
  end
end


valid_adds = []
invalid_adds = []
adds.each do |isbn|
  if StdNum::ISBN.valid?(isbn)
    valid_adds << isbn
  else
    invalid_adds << isbn
  end
end

File.open('audit_adds.txt', 'w') do |add_file|
  valid_adds.each do |isbn|
    add_file << "#{isbn}\n"
  end
end

File.open('audit_deletes.txt', 'w') do |delete_file|
  dels.each do |isbn|
    delete_file << "#{isbn}\n"
  end
end

# Then grep the isbns from the files we just wrote to create
# ingestable/deletable lines:
#   grep -f audit_adds.txt data/comprehensive.txt > UNC_3030_audit_adds.txt
#   grep -f audit_deletes.txt data/holdings.txt > UNC_3030_audit_dels.txt


# 2019-01
# e.g. of isbn in gobi should have holdings 9789522228581
# one lone del: 9780486219912/0486219917
