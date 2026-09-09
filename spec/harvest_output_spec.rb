require 'spec_helper'
require 'tmpdir'

RSpec.describe YBPHoldingsService::Harvest do
  subject(:harvest) do
    described_class.new.tap { |instance| instance.instance_variable_set(:@inst, institution) }
  end

  let(:paths) do
    workdir = @dir
    Module.new do
      const_set(:YBP_VENDOR, File.join(workdir, 'ybp_vendor.txt'))
      const_set(:YBP_ECOLLS, File.join(workdir, 'ybp_ecolls.txt'))
      const_set(:MANUAL_EXCLUDES, File.join(workdir, 'manual_excludes.txt'))
      const_set(:COMPREHENSIVE_NEW, File.join(workdir, 'comprehensive_new.txt'))
    end
  end
  let(:institution) do
    test_paths = paths
    Module.new do
      const_set(:GOBI_ACCOUNT_NO, '3030')
      const_set(:Paths, test_paths)
    end
  end

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  describe '#excluded_isbns' do
    it 'normalizes, deduplicates, and sorts exclusions from every source' do
      File.write(paths::YBP_VENDOR, "978-0-306-40615-7\n")
      File.write(paths::YBP_ECOLLS, "9783161484100\t|tSpringer\n")
      File.write(paths::MANUAL_EXCLUDES, "9780306406157\ninvalid\n")

      expect(harvest.excluded_isbns).to eq([
        '9780306406157',
        '9783161484100'
      ])
      expect(harvest.stats).to include(
        'exc_vendor_code' => 1,
        'exc_ecolls' => 1,
        'exc_manual' => 2,
        'exc_unique' => 2
      )
    end
  end

  describe '#write_comprehensive' do
    it 'writes account-tagged unflagged and flagged ISBNs' do
      harvest.write_comprehensive(
        ['9780306406157'],
        ['9783161484100']
      )

      expect(File.readlines(paths::COMPREHENSIVE_NEW, chomp: true)).to eq([
        '9780306406157|UNC_LOAD|303099',
        '9783161484100|EBOOK_LOAD|303099'
      ])
    end
  end
end
