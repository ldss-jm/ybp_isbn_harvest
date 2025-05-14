module YBPHoldingsService
  # Institutional data
  module Institution
    ABBR = 'UNC'.freeze
    GOBI_ACCOUNT_NO = '3030'.freeze
    EMAIL_ADDRESS = 'eres_cat@unc.edu'.freeze
    SMTP_ADDRESS = 'relay.unc.edu'.freeze
    SMTP_PORT = 25

    ACCT_TAG = "#{ABBR}-#{GOBI_ACCOUNT_NO}".freeze

    EMAIL_SUBJECT = 'Holdings Load Service - UNC-3030 and UNC-4040'.freeze
    EMAIL_BODY_PREFACE = <<~TXT.freeze
      Attached are add/delete file(s) of ISBNs for the Holdings Load Service, UNC
      accounts UNC-3030 and UNC-4040. Please apply these files to both accounts.

      Please add the ISBNs in the add file to our holdings load data and
      delete any ISBNs in the delete file from our holdings load data.
      Thanks!\n
    TXT

    # Paths for result files
    module Paths
      WORKDIR = File.join(__dir__, '..', '..', 'data')
      EBOOK_BNUMS = File.join(WORKDIR, 'results_non_ypb_ebook_ids.txt')
      RAW_ALL_ISBNS = File.join(WORKDIR, 'results_raw_all_isbns.txt')
      PROCESSED_ALL_ISBNS = File.join(WORKDIR, 'results_all_isbns.txt')
      YBP_VENDOR = File.join(WORKDIR, 'results_ybp_vendor.txt')
      YBP_ECOLLS = File.join(WORKDIR, 'results_ybp_ecolls.txt')
      MANUAL_EXCLUDES = File.join(WORKDIR, 'EXCLUDES_gobi.txt')
      COMPREHENSIVE = File.join(WORKDIR, 'comprehensive.txt')
      COMPREHENSIVE_NEW = File.join(WORKDIR, 'comprehensive_new.txt')
      COMPREHENSIVE_OLD = File.join(WORKDIR, 'comprehensive_old.txt')
      STAT_SUMMARY = File.join(WORKDIR, 'run_stats.txt')

      def self.adds
        File.join(WORKDIR, "#{ACCT_TAG}_ADDS_holdings_load.txt")
      end

      def self.deletes
        File.join(WORKDIR, "#{ACCT_TAG}_DELETES_holdings_load.txt")
      end
    end
  end
end
