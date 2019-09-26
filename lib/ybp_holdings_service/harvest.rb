module YBPHoldingsService
  class Harvest
    attr_reader :stats

    def initialize(**opts)
      @opts = opts
      @stats = {}
      @begin_time = Time.now
      @inst = Institution
    end

    def use_existing_query_data?
      @opts[:use_existing_query_data]
    end

    def new_harvest?
      @opts[:new_harvest]
    end

    def paths
      @inst::Paths
    end

    def acct_tag
      @inst::ACCT_TAG
    end

    def queries
      @queries ||= Queries.new(paths)
    end

    def mailer
      @mailer ||= Mailer.new(smtp_address: @inst::SMTP_ADDRESS,
                             smtp_port: @inst::SMTP_PORT)
    end

    def write_stats(key, value)
      stats[key] = value
    end

    def execute
      queries.run_queries unless use_existing_query_data?
      a_isbns, z_isbns = process_all_isbns
      excluded = excluded_isbns

      pre_exclusions_lengths = [a_isbns.length, z_isbns.length]
      remove_excluded!(a_isbns, excluded)
      remove_excluded!(z_isbns, excluded)
      az_stats(a_isbns, z_isbns, pre_exclusions_lengths)

      write_comprehensive(a_isbns, z_isbns)

      old = new_harvest? ? [] : File.foreach(paths::COMPREHENSIVE, chomp: true).sort
      new = File.foreach(paths::COMPREHENSIVE_NEW, chomp: true).sort

      delta = Delta.new(old, new)
      delta.write_deletes(paths.deletes)
      write_stats('deletes', delta.delete_count)
      delta.write_adds(paths.adds)
      write_stats('adds', delta.add_count)

      # conclude
      File.write(paths::STAT_SUMMARY, email_body)
      archive_files
      mailer.send_mail(email_address, email_subject, email_body,
                       [paths.adds, paths.deletes])

      FileUtils.cp(@zipfile_path, paths.common_dir)
    end

    def az_stats(a_isbns, z_isbns, pre_exclusions_lengths)
      write_stats('unflagged', a_isbns.length)
      write_stats('flagged', z_isbns.length)
      write_stats('found_unique', pre_exclusions_lengths.sum)
      sent = a_isbns.length + z_isbns.length
      write_stats('sent', sent)
      write_stats('excluded', pre_exclusions_lengths.sum - sent)
    end

    def process_all_isbns
      # normalize and split by subfield
      # result in an a_isbns
      # and a z_isbns with any a_isbn removed
      a_isbns = Set.new()
      z_isbns = Set.new()

      isbn_count = 0
      invalid_isbn_count = 0
      wrote_a = nil
      wrote_z = nil

      e_bnums = non_ybp_ebook_rec_ids

      File.foreach(paths::ALL_ISBNS, chomp: true) do |line|
        isbn_count += 1
        bnum, tag, isbn = line.split("\t")
        isbn_normalized = ISBN.normalize_isbn(isbn)
        unless isbn_normalized
          invalid_isbn_count += 1
          next
        end
        if tag == 'a'
          a_isbns << isbn_normalized
          wrote_a = bnum

        # skip if we just wrote an a_isbn from this record
        # this saves us from the e_bnums binary search.
        elsif wrote_a == bnum
          next

        # write if: we just wrote a z_isbn from this record
        # or it's an ecoll record that we have not already seen with an a_isbn
        elsif wrote_z == bnum || e_bnums.bsearch { |x| bnum <=> x }
          z_isbns << isbn_normalized
          wrote_z = bnum
        end
      end

      z_isbns = z_isbns - a_isbns
      write_stats('found', isbn_count)
      write_stats('invalid', invalid_isbn_count)

      [a_isbns, z_isbns]
    end

    def non_ybp_ebook_rec_ids
      lines = File.readlines(paths::EBOOK_BNUMS, chomp: true).sort
      write_stats('non_ybp_ebook_rec_ids', lines.length)
      lines
    end

    def ybp_ecoll_isbns
      lines = File.readlines(paths::YBP_ECOLLS, chomp: true).uniq
      ecoll_stats_by_collection(lines)
      write_stats('exc_ecolls', lines.length)
      lines
    end

    def ecoll_stats_by_collection(lines)
      by_colls = lines.group_by do |x|
        case x
        when /Springer/i
          'Springer'
        when /title-by-title/i
          'title-by-title through YBP'
        when /via YBP/i
          'title-by-title through YBP'
        when /ProQuest Ebook Central .online collection.\. DDA/i
          'YBP EBL DDA'
        when /ProQuest Ebook Central DDA .online collection.\./i
          'YBP EBL DDA'
        when /EBL eBook Library DDA/i
          'YBP EBL DDA'
        when /Cambridge histories online/i
          'Cambridge'
        when /Duke University Press/i
          'Duke'
        else
          x
        end
      end
      write_stats('by_ecoll', by_colls.map { |k,v| [k, v.length] })
    end

    def ybp_vendor_isbns
      lines = File.readlines(paths::YBP_VENDOR, chomp: true).uniq
      write_stats('exc_vendor_code', lines.length)
      lines
    end

    def manual_excludes
      lines = File.readlines(paths::MANUAL_EXCLUDES, chomp: true).uniq
      write_stats('exc_manual', lines.length)
      lines
    end

    def excluded_isbns
      exc = (ybp_vendor_isbns + ybp_ecoll_isbns + manual_excludes).
            sort.uniq.
            map { |x| ISBN.normalize_isbn(x) }.
            compact.uniq.sort
      write_stats('exc_unique', exc.length)
      exc
    end

    def remove_excluded!(set, exclusions)
      set.delete_if { |isbn| exclusions.bsearch { |x| isbn <=> x } }
    end

    def write_comprehensive(a_isbns, z_isbns)
      acct_no = "#{@inst::GOBI_ACCOUNT_NO}99"
      File.open(paths::COMPREHENSIVE_NEW, 'w') do |file|
        {unc_load: a_isbns, ebook_load: z_isbns}.each do |tag, isbns|
          isbns.each { |isbn| file << "#{isbn}|#{tag}|#{acct_no}\n"}
        end
      end
    end

    def archive_files
      file_timestamp = Time.now.strftime('%F_%H%M%S')
      @zipfile_path = File.join(paths::WORKDIR, "load_#{file_timestamp}.zip")
      Zip::File.open(@zipfile_path, Zip::File::CREATE) do |zipfile|
        zipfile.add(File.basename(paths.adds), paths.adds)
        zipfile.add(File.basename(paths.deletes), paths.deletes)
        zipfile.add(File.basename(paths::COMPREHENSIVE_NEW), paths::COMPREHENSIVE_NEW)
        zipfile.add('comprehensive_prev.txt', paths::COMPREHENSIVE)
        zipfile.add(File.basename(paths::EBOOK_BNUMS), paths::EBOOK_BNUMS)
        zipfile.add(File.basename(paths::ALL_ISBNS), paths::ALL_ISBNS)
        zipfile.add(File.basename(paths::YBP_VENDOR), paths::YBP_VENDOR)
        zipfile.add(File.basename(paths::YBP_ECOLLS), paths::YBP_ECOLLS)
        zipfile.add(File.basename(paths::STAT_SUMMARY), paths::STAT_SUMMARY)
      end

      FileUtils.mv(paths::COMPREHENSIVE, paths::COMPREHENSIVE_OLD)
      FileUtils.mv(paths::COMPREHENSIVE_NEW, paths::COMPREHENSIVE)
    end

    def email_address
      @inst::EMAIL_ADDRESS
    end

    def email_subject
      "#{@inst::ACCT_TAG} Holdings Load Service"
    end

    def email_body_preface
      <<~TXT
        Attached are add/delete file(s) of ISBNs for the Holdings Load Service,
        #{@inst::ABBR} account #{@inst::GOBI_ACCOUNT_NO}.

        Please add the ISBNs in the add file to our holdings load data, and
        please delete any ISBNs in the delete file from our holdings load data.
        Thanks!\n
      TXT
    end

    def email_body
      stat_ecoll_details = ''
      stats['by_ecoll'].sort_by! { |x| x[1]}
      stats['by_ecoll'].each do |coll, count|
        stat_ecoll_details += "  --#{coll}...#{count}\n"
      end

      <<~BODY
        #{email_body_preface}
        -----------------------
        Auto-generated info:
        Delta Adds: #{stats['adds']}
        Delta Deletes: #{stats['deletes']}
        Comprehensive ISBNs: #{stats['sent']}
        ISBNs found: #{stats['found']}
        --unique: #{stats['found_unique']}
        --invalid ISBNs: #{stats['invalid']}
        --excluded ISBNs:  #{stats['excluded']}
        ------------
        YBP ISBNs to exclude, unique: #{stats['exc_unique']}
        --vendor code: #{stats['exc_vendor_code']}
        --ecolls: #{stats['exc_ecolls']}
        #{stat_ecoll_details.rstrip}
        --manual: #{stats['exc_manual']}
        ------------
        unflagged found: #{stats['unflagged']}
        flagged found: #{stats['flagged']}
        ------------
        Began: #{@begin_time}
        Finished: #{Time.now}
      BODY
    end

    class Mailer
      def initialize(smtp_address:, smtp_port:)
        smtp = {address: smtp_address, port: smtp_port}
        @smtp = smtp

        Mail.defaults do
          delivery_method :smtp, address: smtp[:address], port: smtp[:port]
        end
      end

      def send_mail(address, subject, body, attachments = [])
        Mail.deliver do
          from     address
          to       address
          subject  subject
          body     body

          attachments.each { |file| add_file file if File.size?(file) }
        end
      end
    end

    class Queries
      def initialize(paths)
        @paths = paths
      end

      def run_queries
        Queries.query_non_ybp_ebook_ids(@paths::EBOOK_BNUMS)
        Queries.query_all_isbns(@paths::ALL_ISBNS)
        Queries.query_ybp_ecolls(@paths::YBP_ECOLLS)
        Queries.query_ybp_vendor(@paths::YBP_VENDOR)
      end

      def self.query(sql_file, outpath)
        Sierra::DB.query(File.read(File.join(__dir__, 'queries', sql_file)))
        Sierra::DB.write_results(outpath, include_headers: false)
      end

      # Ebook record ids -- acceptable to use 020|z if there is no 020|a
      def self.query_non_ybp_ebook_ids(path)
        query('non_ybp_ebook_ids.sql', path)
      end

      # All isbns (020|az)
      def self.query_all_isbns(path)
        query('all_isbns.sql', path)
      end

      # ISBNs to be excluded due to e-collection is from ybp
      def self.query_ybp_ecolls(path)
        query('ybp_ecolls.sql', path)
      end

      # ISBNs to be excluded due to vendor=ybp
      def self.query_ybp_vendor(path)
        query('ybp_vendor.sql', path)
      end
    end

    class Delta
      attr_reader :add_count, :delete_count

      def initialize(old, new)
        @old = old
        @new = new
      end

      def write_deletes(path)
        @delete_count = Delta.write_deletes(@old, @new, path)
      end

      def write_adds(path)
        @add_count = Delta.write_adds(@old, @new, path)
      end

      def self.write_deletes(old, new, path)
        count = 0
        File.open(path, 'w') do |delete_file|
          old.each do |old_line|
            unless new.bsearch { |x| old_line <=> x }
              delete_file << old_line + "\n"
              count += 1
            end
          end
        end
        count
      end

      def self.write_adds(old, new, path)
        count = 0
        File.open(path, 'w') do |add_file|
          new.each do |new_line|
            unless old.bsearch { |x| new_line <=> x }
              add_file << new_line + "\n"
              count += 1
            end
          end
        end
        count
      end
    end
  end

  module ISBN
    def self.normalize_isbn(isbn_subfield_string)
      # We don't want to use StdNum::ISBN.normalize which would also
      # convert 10 digit ISBN's to 13 digit. YBP stores all ISBNs as ISBN-13s,
      # so once the next yearly reconciliation occurs, we can covert our
      # comprehensive list to all ISBN-13 and use that for the reconciliation.
      #
      # Similarly: at that reconciliation we can also stop sending them invalid
      # ISBNs
      isbn = StdNum::ISBN.reduce_to_basics(isbn_subfield_string, [10, 13])

      # uncommentable at next reconciliation
      # return isbn if StdNum::ISBN.valid?(isbn)
    end
  end
end
