require 'spec_helper'
require 'tmpdir'

RSpec.describe YBPHoldingsService::Harvest do
  subject(:harvest) do
    described_class.new.tap { |instance| instance.instance_variable_set(:@inst, institution) }
  end

  let(:paths) do
    workdir = @dir
    Module.new do
      const_set(:WORKDIR, workdir)
      const_set(:EBOOK_BNUMS, File.join(workdir, 'ebook_bnums.txt'))
      const_set(:RAW_ALL_ISBNS, File.join(workdir, 'raw_isbns.txt'))
      const_set(:YBP_VENDOR, File.join(workdir, 'ybp_vendor.txt'))
      const_set(:YBP_ECOLLS, File.join(workdir, 'ybp_ecolls.txt'))
      const_set(:COMPREHENSIVE, File.join(workdir, 'comprehensive.txt'))
      const_set(:COMPREHENSIVE_NEW, File.join(workdir, 'comprehensive_new.txt'))
      const_set(:COMPREHENSIVE_OLD, File.join(workdir, 'comprehensive_old.txt'))
      const_set(:STAT_SUMMARY, File.join(workdir, 'run_stats.txt'))

      define_singleton_method(:adds) { File.join(workdir, 'adds.txt') }
      define_singleton_method(:deletes) { File.join(workdir, 'deletes.txt') }
    end
  end
  let(:institution) do
    test_paths = paths
    Module.new { const_set(:Paths, test_paths) }
  end

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  before do
    {
      paths.adds => "add\n",
      paths.deletes => "delete\n",
      paths::COMPREHENSIVE_NEW => "new\n",
      paths::EBOOK_BNUMS => "b100\n",
      paths::RAW_ALL_ISBNS => "raw\n",
      paths::YBP_VENDOR => "vendor\n",
      paths::YBP_ECOLLS => "ecoll\n",
      paths::STAT_SUMMARY => "stats\n"
    }.each { |path, content| File.write(path, content) }
  end

  describe '#archive_files' do
    it 'archives and promotes new state without requiring previous state' do
      harvest.archive_files

      entries = archive_entries
      expect(entries).to include('comprehensive_new.txt')
      expect(entries).not_to include('comprehensive_prev.txt')
      expect(File.read(paths::COMPREHENSIVE)).to eq("new\n")
      expect(File).not_to exist(paths::COMPREHENSIVE_OLD)
    end

    it 'archives and rotates previous state for a recurring harvest' do
      File.write(paths::COMPREHENSIVE, "previous\n")

      harvest.archive_files

      expect(archive_entries).to include('comprehensive_prev.txt')
      expect(File.read(paths::COMPREHENSIVE_OLD)).to eq("previous\n")
      expect(File.read(paths::COMPREHENSIVE)).to eq("new\n")
    end
  end

  def archive_entries
    archive_path = Dir[File.join(@dir, 'load_*.zip')].fetch(0)
    Zip::File.open(archive_path) { |zipfile| zipfile.entries.map(&:name) }
  end
end
