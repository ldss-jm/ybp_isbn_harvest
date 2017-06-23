require 'fileutils'
require 'set'
require 'mail'
require 'zip'
require 'csv'
load '../postgres_connect/connect.rb'


WORKDIR = 'data'
EBOOK_BNUMS_PATH = File.join(WORKDIR, 'ebook_bnums_results.txt')
ALL_ISBNS_PATH = File.join(WORKDIR, 'all_isbns_results.txt')
YBP_VENDOR_PATH = File.join(WORKDIR, 'ybp_vendor_isbns_results.txt')
YBP_ECOLLS_PATH = File.join(WORKDIR, 'ybp_ecolls_isbns_results.txt')
excludes_gobi_path = File.join(WORKDIR, 'EXCLUDES_gobi.txt')
comp_path = File.join(WORKDIR, 'comprehensive.txt')
comp_new_path = File.join(WORKDIR, 'comprehensive_new.txt')
comp_old_path = File.join(WORKDIR, 'comprehensive_old.txt')
adds_path = File.join(WORKDIR, 'UNC-3030_ADDS_holdings_load.txt')
deletes_path = File.join(WORKDIR, 'UNC-3030_DELETES_holdings_load.txt')
common_dir = 'H:/GOBI Library Solutions/archive/'

# Set mail defaults, grab email address from postgres_connect
#
Mail.defaults do
  delivery_method :smtp, address: "relay.unc.edu", port: 25
end
c = Connect.new
email_address = c.emails['eres']
#email_address = c.emails['default_email']
c.close

#
# functions
#

def normalize_isbn(isbn_subfield_string)
  validate_isbn(strip_isbn(isbn_subfield_string))
end

def strip_isbn(isbn)
  # strips a leading isbn from an entire 020 subfield string
  return isbn.upcase.match(/^[- 0-9X]*/)[0].strip
rescue NoMethodError
  return nil
end

def validate_isbn(isbn)
  # checks for proper isbn structure, but not for properly calculated check digit
  # returns nil for invalid isbn
  # returns normalized isbn for valid isbns (i.e. 10 or 13 chars of 0-9X; no spaces, hyphens, etc.)
  # isbn regexp from:
  # https://www.safaribooksonline.com/library/view/regular-expressions-cookbook/9781449327453/ch04s13.html
  # comment toggling would allow 9 digit SBNs, which would be prefixed with a 0 to make
  # a 10 digit ISBN
  # Allow SBN regexp:
  #(regexp = '^(?:ISBN(?:-1[03])?:? )?(?=[0-9X]{9,10}$|(?=(?:[0-9]+[- ]){3})' +
  #          '[- 0-9X]{12,13}$|97[89][0-9]{10}$|(?=(?:[0-9]+[- ]){4})[- 0-9]{17}$)' +
  #          '(?:97[89][- ]?)?[0-9]{1,5}[- ]?[0-9]+[- ]?[0-9]+[- ]?[0-9X]$')
  # Only ISBN regexp:
  (regexp = '^(?:ISBN(?:-1[03])?:? )?(?=[0-9X]{10}$|(?=(?:[0-9]+[- ]){3})' +
            '[- 0-9X]{13}$|97[89][0-9]{10}$|(?=(?:[0-9]+[- ]){4})[- 0-9]{17}$)' +
            '(?:97[89][- ]?)?[0-9]{1,5}[- ]?[0-9]+[- ]?[0-9]+[- ]?[0-9X]$')
  isbn = isbn.match(regexp)[0]
  #if isbn.length == 9 # allows for SBNs
  # isbn = '0' + isbn  # allows for SBNs
  #end                 # allows for SBNs
  return isbn.gsub('-', '').gsub(' ', '').match(/[0-9X]*$/)[0]
rescue NoMethodError
  return nil
end

def run_queries()
    puts 'ebook_bnums'
    load 'ebook_bnums.rb'
    puts 'all_isbns'
    load 'all_isbns.rb'
    puts 'ybp_ecolls_isbns'
    load 'ybp_ecolls_isbns.rb'
    puts 'ybp_vendor_isbns'
    load 'ybp_vendor_isbns.rb'
    puts "\n"
end


#
# Run script
#



timestamp = Time.now.to_s
if ARGV[0] == '--read'
  puts 'skipping queries, reading results from file'
else
  files_to_delete = []
  puts 'running queries'
  run_queries
end

e_bnums = File.read(EBOOK_BNUMS_PATH).split("\n")
e_bnums.sort!

puts 'rolling all_isbns into records ' + Time.now.to_s
records = {}
stat_isbns_found = 0
stat_invalid_isbns = 0
# make hash of: bib records, as hashes with tags => valid isbns
a_isbns = Set.new()
z_isbns = Set.new()
IO.foreach(ALL_ISBNS_PATH) do |line|
  stat_isbns_found += 1
  bnum, tag, isbn = line.split("\t")
  isbn_normalized = normalize_isbn(isbn)
  unless isbn_normalized
    stat_invalid_isbns += 1
  end
  if e_bnums.bsearch { |x| bnum <=> x }
    if records.include? bnum
      records[bnum][tag.to_sym] << isbn_normalized
    else
      records[bnum] = {a: [], z: []}
      records[bnum][tag.to_sym] << isbn_normalized
    end
  elsif tag == 'a'
    a_isbns << isbn_normalized
  end
end

puts '..getting ecoll a_isbns and z_isbns ' + Time.now.to_s


# for each ecoll bib, get 020|a; if no 020|a, get 020|z
bnum, record = records.shift
while record
  if not record[:a].compact.empty?
    record[:a].compact.each do |isbn|
      a_isbns << isbn
    end
  else
    record[:z].compact.each do |isbn|
      z_isbns << isbn
    end
  end
  bnum, record = records.shift
end

# remove anything from z_isbns if in a_isbns
z_isbns = z_isbns - a_isbns

#
# Remove YBP ISBNs
#
puts 'finding exclude_isbns ' + Time.now.to_s
ybp_vendor_isbns = File.read(YBP_VENDOR_PATH).split("\n")
stat_ybp_vendor_code = ybp_vendor_isbns.uniq.length
ybp_ecolls_isbns = File.read(YBP_ECOLLS_PATH).split("\n")
stat_ybp_ecolls_by_coll =
            ybp_ecolls_isbns.group_by{
              |x| case
                  when x.match(/Springer/) then 'Springer'
                  when x.match(/title-by-title/i) then 'title-by-title through YBP'
                  when x.match(/via YBP/i) then 'title-by-title through YBP'
                  when x.match(/ProQuest Ebook Central/) then 'YBP EBL DDA'
                  when x.match(/EBL eBook Library DDA/) then 'YBP EBL DDA'
                  when x.match(/Cambridge histories online/) then 'Cambridge'
                  when x.match(/Duke University Press/) then 'Duke'
                  end
              }.map{ |k,v| [k, v.length]
            }
ybp_ecolls_isbns = ybp_ecolls_isbns.map{ |x| x.split("\t")[0]}
stat_ybp_ecolls = ybp_ecolls_isbns.uniq.length
manual_excludes = File.read(excludes_gobi_path).split("\n")
stat_manual_isbns_to_exclude = manual_excludes.length
exclude_isbns = (ybp_vendor_isbns + ybp_ecolls_isbns + manual_excludes).sort.uniq
ybp_vendor_isbns = nil
ybp_ecolls_isbns = nil


exclude_isbns.map! { |x| strip_isbn(x)}
exclude_isbns = exclude_isbns.compact.uniq
exclude_isbns.sort!
stat_ybp_isbns_to_exclude = exclude_isbns.length

puts 'finding include_isbns ' + Time.now.to_s


stat_unique_found = a_isbns.length + z_isbns.length
[a_isbns, z_isbns].each do |this_set|
  this_set.delete_if { |isbn| exclude_isbns.bsearch { |x| isbn <=> x } }
end
stat_020_a = a_isbns.length
stat_020_z = z_isbns.length
stat_excluded = stat_unique_found - stat_020_a - stat_020_z


# Write ISBNs for holdings load data
#
puts 'writing files '  + Time.now.to_s
File.open(comp_new_path, 'w') do |file|
  a_isbns.each do |a_isbn|
    if a_isbn
      file << "#{a_isbn}||303099\n"
    end
  end
  z_isbns.each do |z_isbn|
    if z_isbn
      file << "#{z_isbn}|ebook|303099\n"
    end
  end
end


#
# Generate delta files
#
puts '..making delta files '  + Time.now.to_s
comp_prev = []
CSV.foreach(comp_path, :col_sep => "|") do |isbn, tag, *|
  comp_prev << isbn
end
comp_new = []
comp_new_data = []
CSV.foreach(comp_new_path, :col_sep => "|") do |isbn, tag, *|
  comp_new << isbn
  comp_new_data << [isbn, tag]
end
comp_prev = comp_prev.compact.sort
comp_new = comp_new.compact.sort
comp_new_data = comp_new.compact.sort

puts '..writing delta files '  + Time.now.to_s
stat_deletes = 0
stat_adds = 0
File.open(deletes_path, 'w') do |delete_file|
  comp_prev.each do |prev_isbn|
    unless comp_new.bsearch { |x| prev_isbn <=> x }
      delete_file << "#{prev_isbn}||303099\n"
      stat_deletes += 1
    end
  end
end
File.open(adds_path, 'w') do |add_file|
  comp_new_data.each do |isbn, tag|
    unless comp_prev.bsearch { |x| isbn <=> x }
      add_file << "#{isbn}|#{tag}|303099\n"
      stat_adds += 1
    end
  end
end

file_timestamp = Time.now.strftime("%F_%H%M%S")
zipfile_path =  File.join(WORKDIR, "load_#{file_timestamp}.zip")
Zip::File.open(zipfile_path, Zip::File::CREATE) do |zipfile|
  zipfile.add('UNC-3030_ADDS_holdings_load.txt', adds_path)
  zipfile.add('UNC-3030_DELETES_holdings_load.txt', deletes_path)
  zipfile.add('comprehensive_new.txt', comp_new_path)
  zipfile.add('comprehensive_prev.txt', comp_path)
  zipfile.add('results_ebooks_bnums.txt', EBOOK_BNUMS_PATH)
  zipfile.add('results_all_isbns.txt', ALL_ISBNS_PATH)
  zipfile.add('results_ybp_vendor.txt', YBP_VENDOR_PATH)
  zipfile.add('results_ybp_ecolls.txt', YBP_ECOLLS_PATH)
end

FileUtils.mv(comp_path, comp_old_path)
FileUtils.mv(comp_new_path, comp_path)
FileUtils.cp(zipfile_path, common_dir)
stat_isbns_sent = stat_020_a + stat_020_z



#
# Send results by mail
#
puts 'sending mail'
stat_ecoll_details = ''
stat_ybp_ecolls_by_coll.sort_by!{ |x| x[1]}
stat_ybp_ecolls_by_coll.each do |coll, count|
  stat_ecoll_details += "  --#{coll}...#{count}\n"
end


mailbody = <<-EOT
Attached are add/delete file(s) of ISBNs for the Holdings Load Service, UNC
account 3030. Please add the ISBNs in the add file to our holdings load data,
and please delete any ISBNs in the delete file from our holdings load data.
Thanks!\n\n
-----------------------
Auto-generated info:
Delta Adds: #{stat_adds}
Delta Deletes: #{stat_deletes}
Comprehensive ISBNs: #{stat_isbns_sent}
ISBNs found: #{stat_isbns_found}
--unique: #{stat_unique_found}
--invalid ISBNs: #{stat_invalid_isbns}
--excluded ISBNs:  #{stat_excluded}
------------
YBP ISBNs to exclude, unique: #{stat_ybp_isbns_to_exclude}
--vendor code: #{stat_ybp_vendor_code}
--ecolls: #{stat_ybp_ecolls}
#{stat_ecoll_details.rstrip}
--manual: #{stat_manual_isbns_to_exclude}
------------
unflagged found: #{stat_020_a}
flagged found: #{stat_020_z}
------------
Began: #{timestamp}
Finished: #{Time.now.to_s}
EOT

Mail.deliver do
  from     email_address
  to       email_address
  subject  'UNC-3030 Holdings Load Service'
  body     mailbody
  attachments = [adds_path, deletes_path]
  attachments.each do |filename|
    if File.size?(filename)
      add_file filename
    end
  end
end