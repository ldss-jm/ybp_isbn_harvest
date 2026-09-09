require 'spec_helper'
require 'tmpdir'

RSpec.describe YBPHoldingsService::Harvest do
  subject(:harvest) { described_class.new }

  around do |example|
    Dir.mktmpdir do |dir|
      @input_path = File.join(dir, 'raw_isbns.txt')
      @output_path = File.join(dir, 'processed_isbns.txt')
      example.run
    end
  end

  describe '#process_raw_isbns' do
    it 'attributes a completed group to its record and sorts its subfields' do
      File.write(
        @input_path,
        "b100\t|zFirst z|aFirst a\n" \
        "b100\t|qIgnored|aSecond a\n" \
        "b200\t|aLast a\n"
      )

      harvest.process_raw_isbns(@input_path, @output_path)

      first_group = File.readlines(@output_path, chomp: true).
                    select { |line| line.match?(/First|Second/) }
      expect(first_group).to eq([
        "b100\ta\tFirst a",
        "b100\ta\tSecond a",
        "b100\tz\tFirst z"
      ])
    end

    it 'writes the final record group' do
      File.write(@input_path, "b200\t|zLast z|aLast a\n")

      harvest.process_raw_isbns(@input_path, @output_path)

      expect(File.readlines(@output_path, chomp: true)).to eq([
        "b200\ta\tLast a",
        "b200\tz\tLast z"
      ])
    end
  end
end
