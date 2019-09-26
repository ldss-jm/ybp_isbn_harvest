module YBPHoldingsService
  # Institutional data
  module Institution
    ABBR = 'UNC'
    GOBI_ACCOUNT_NO = '3030'
    EMAIL_ADDRESS = 'eres_cat@unc.edu'
    SMTP_ADDRESS = 'relay.unc.edu'
    SMTP_PORT = 25

    ACCT_TAG = "#{ABBR}-#{GOBI_ACCOUNT_NO}"

    # Paths for result files
    module Paths
      WORKDIR = File.join(__dir__, '..', '..', 'data')
      EBOOK_BNUMS = File.join(WORKDIR, 'results_non_ypb_ebook_ids.txt')
      ALL_ISBNS = File.join(WORKDIR, 'results_all_isbns.txt')
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

      COMMON_SYMLINK = '/mnt/ybp_holdings_load/'
      COMMON_FILEPATH = '\\\\ad.unc.edu\\lib\\common\\GOBI Library Solutions\\archive\\'

      # Path where archival zip file is copied.
      def self.common_dir
        if File.directory?(Paths::COMMON_SYMLINK)
          Paths::COMMON_SYMLINK
        else
          Paths::COMMON_FILEPATH
        end
      end
    end
  end
end
