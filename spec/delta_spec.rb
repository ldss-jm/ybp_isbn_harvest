require 'spec_helper'
require 'tmpdir'

RSpec.describe YBPHoldingsService::Harvest::Delta do
  let(:old_holdings) do
    [
      '1111111111111|UNC_LOAD|303099',
      '2222222222222|UNC_LOAD|303099'
    ]
  end
  let(:new_holdings) do
    [
      '2222222222222|UNC_LOAD|303099',
      '3333333333333|EBOOK_LOAD|303099'
    ]
  end
  let(:delta) { described_class.new(old_holdings, new_holdings) }

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  it 'writes additions and records their count' do
    path = File.join(@dir, 'adds.txt')

    delta.write_adds(path)

    expect(File.readlines(path, chomp: true)).
      to eq(['3333333333333|EBOOK_LOAD|303099'])
    expect(delta.add_count).to eq(1)
  end

  it 'writes deletions and records their count' do
    path = File.join(@dir, 'deletes.txt')

    delta.write_deletes(path)

    expect(File.readlines(path, chomp: true)).
      to eq(['1111111111111|UNC_LOAD|303099'])
    expect(delta.delete_count).to eq(1)
  end
end
