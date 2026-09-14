require 'spec_helper'

RSpec.describe YBPHoldingsService::ISBN do
  describe '.normalize_isbn' do
    it 'normalizes a valid ISBN' do
      expect(described_class.normalize_isbn('978-0-306-40615-7')).
        to eq('9780306406157')
    end

    it 'rejects an invalid ISBN' do
      expect(described_class.normalize_isbn('not an isbn')).to be_nil
    end
  end
end
