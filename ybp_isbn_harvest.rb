#!/usr/bin/env ruby
require 'fileutils'
require 'set'
require 'mail'
require 'zip'
require 'csv'
require_relative '../postgres_connect/connect.rb'


WORKDIR = File.join(__dir__, 'data')
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

common_symlink = '/mnt/ybp_holdings_load/'
common_dir =
  if File.directory?(common_symlink)
    common_symlink
  else
    '\\\\ad.unc.edu\\lib\\common\\GOBI Library Solutions\\archive\\'
  end


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
  # TODO: allow prefixes like "ISBN-13: 9781231231231"
  return isbn.upcase.match(/^[- 0-9X]*/)[0].strip
rescue NoMethodError
  return nil
end

def validate_isbn(isbn)
  # checks for proper isbn structure, but not for properly calculated check digit
  # returns nil for invalid isbn
  # for valid isbns, returns normalized isbn (i.e. 10 or 13 chars of 0-9X; no spaces, hyphens, etc.)
  # isbn regexp from:
  # https://www.safaribooksonline.com/library/view/regular-expressions-cookbook/9781449327453/ch04s13.html
  # Only ISBN regexp:
  (regexp = '^(?:ISBN(?:-1[03])?:? )?(?=[0-9X]{10}$|(?=(?:[0-9]+[- ]){3})' +
            '[- 0-9X]{13}$|97[89][0-9]{10}$|(?=(?:[0-9]+[- ]){4})[- 0-9]{17}$)' +
            '(?:97[89][- ]?)?[0-9]{1,5}[- ]?[0-9]+[- ]?[0-9]+[- ]?[0-9X]$')
  isbn = isbn.match(regexp)[0]
  return isbn.gsub('-', '').gsub(' ', '').match(/[0-9X]*$/)[0]
rescue NoMethodError
  return nil
end

def run_queries()
    puts 'ebook_bnums'
    load File.join(__dir__, 'ebook_bnums.rb')
    puts 'all_isbns'
    load File.join(__dir__, 'all_isbns.rb')
    puts 'ybp_ecolls_isbns'
    load File.join(__dir__, 'ybp_ecolls_isbns.rb')
    puts 'ybp_vendor_isbns'
    load File.join(__dir__, 'ybp_vendor_isbns.rb')
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

puts 'finding normalized |a and |z isbns to include' + Time.now.to_s
# take all |a isbns and |z isbns for ecoll records where there is no |a
# this part relies on the sql results being sorted by record and subfield
# indicator
wrote_a = ''
wrote_z = ''
stat_isbns_found = 0
stat_invalid_isbns = 0
a_isbns = Set.new()
z_isbns = Set.new()

File.foreach(ALL_ISBNS_PATH) do |line|
  stat_isbns_found += 1
  bnum, tag, isbn = line.split("\t")
  isbn_normalized = normalize_isbn(isbn)
  stat_invalid_isbns += 1 unless isbn_normalized
  if tag == 'a'
    a_isbns << isbn_normalized
    wrote_a = bnum if isbn_normalized

  # skip if we just wrote an a_isbn from this record
  # this saves us from the e_bnums binary search.
  elsif wrote_a == bnum

  # write if: we just wrote a z_isbn from this record
  # or it's an ecoll record that we have not already seen with an a_isbn
  elsif wrote_z == bnum || e_bnums.bsearch { |x| bnum <=> x }
      z_isbns << isbn_normalized
      wrote_z = bnum
  end
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
        when x.match(/Springer/i) then 'Springer'
        when x.match(/title-by-title/i) then 'title-by-title through YBP'
        when x.match(/via YBP/i) then 'title-by-title through YBP'
        when x.match(/ProQuest Ebook Central .online collection.\. DDA/i) then 'YBP EBL DDA'
        when x.match(/ProQuest Ebook Central DDA .online collection.\./i) then 'YBP EBL DDA'
        when x.match(/EBL eBook Library DDA/i) then 'YBP EBL DDA'
        when x.match(/Cambridge histories online/i) then 'Cambridge'
        when x.match(/Duke University Press/i) then 'Duke'
        else x
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


exclude_isbns.map! { |x| strip_isbn(x) }
exclude_isbns = exclude_isbns.compact.uniq
exclude_isbns.sort!
stat_ybp_isbns_to_exclude = exclude_isbns.length

puts 'excluding exclude_isbns ' + Time.now.to_s


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
  a_isbns.each { |a_isbn| file << "#{a_isbn}|unc_load|303099\n" if a_isbn }
  z_isbns.each { |z_isbn| file << "#{z_isbn}|ebook_load|303099\n" if z_isbn }
end


#
# Generate delta files
#
puts '..making delta files '  + Time.now.to_s
comp_prev = []
comp_new = []
File.foreach(comp_path) { |line| comp_prev << line.rstrip }
File.foreach(comp_new_path) { |line| comp_new << line.rstrip }

comp_prev = comp_prev.compact.sort
comp_new = comp_new.compact.sort

puts '..writing delta files '  + Time.now.to_s
stat_deletes = 0
stat_adds = 0
File.open(deletes_path, 'w') do |delete_file|
  comp_prev.each do |prev_line|
    unless comp_new.bsearch { |x| prev_line <=> x }
      delete_file << prev_line + "\n"
      stat_deletes += 1
    end
  end
end

File.open(adds_path, 'w') do |add_file|
  comp_new.each do |new_line|
    unless comp_prev.bsearch { |x| new_line <=> x }
      add_file << new_line + "\n"
      stat_adds += 1
     end
  end
end

stat_isbns_sent = stat_020_a + stat_020_z
stat_ecoll_details = ''
stat_ybp_ecolls_by_coll.sort_by! { |x| x[1]}
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

puts mailbody
File.write('run_stats.txt', mailbody)

file_timestamp = Time.now.strftime("%F_%H%M%S")
zipfile_path = File.join(WORKDIR, "load_#{file_timestamp}.zip")
Zip::File.open(zipfile_path, Zip::File::CREATE) do |zipfile|
  zipfile.add('UNC-3030_ADDS_holdings_load.txt', adds_path)
  zipfile.add('UNC-3030_DELETES_holdings_load.txt', deletes_path)
  zipfile.add('comprehensive_new.txt', comp_new_path)
  zipfile.add('comprehensive_prev.txt', comp_path)
  zipfile.add('results_ebooks_bnums.txt', EBOOK_BNUMS_PATH)
  zipfile.add('results_all_isbns.txt', ALL_ISBNS_PATH)
  zipfile.add('results_ybp_vendor.txt', YBP_VENDOR_PATH)
  zipfile.add('results_ybp_ecolls.txt', YBP_ECOLLS_PATH)
  zipfile.add('run_stats.txt', 'run_stats.txt')
end

FileUtils.mv(comp_path, comp_old_path)
FileUtils.mv(comp_new_path, comp_path)

#
# Send results by mail
#
puts 'sending mail'

Mail.deliver do
  from     email_address
  to       email_address
  subject  'UNC-3030 Holdings Load Service'
  body     mailbody
  attachments = [adds_path, deletes_path]
  attachments.each do |filename|
    add_file filename if File.size?(filename)
  end
end

FileUtils.cp(zipfile_path, common_dir)
