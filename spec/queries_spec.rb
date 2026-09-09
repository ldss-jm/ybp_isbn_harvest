require 'spec_helper'

RSpec.describe YBPHoldingsService::Harvest::Queries do
  describe '.query' do
    let(:database) { class_double('Sierra::DB') }
    let(:query_error) { Class.new(StandardError) }

    before do
      allow(described_class).to receive(:require).and_call_original
      allow(described_class).to receive(:require).
        with('sierra_postgres_utilities').and_return(false)
      stub_const('Sierra', Module.new)
      stub_const('Sierra::DB', database)
      stub_const('PG', Module.new)
      stub_const('PG::QueryCanceled', query_error)
      stub_const('Sequel', Module.new)
      stub_const('Sequel::DatabaseError', Class.new(StandardError))
      allow(database).to receive(:write_results)
    end

    it 'writes query results without headers' do
      allow(database).to receive(:query)

      described_class.query('ybp_vendor.sql', 'results.txt')

      expect(database).to have_received(:query).with(include('vendor_record_code'))
      expect(database).to have_received(:write_results).
        with('results.txt', include_headers: false)
    end

    it 'waits and retries once after a canceled query' do
      attempts = 0
      allow(database).to receive(:query) do
        attempts += 1
        raise query_error if attempts == 1
      end
      allow(described_class).to receive(:sleep)

      described_class.query('ybp_vendor.sql', 'results.txt')

      expect(database).to have_received(:query).twice
      expect(described_class).to have_received(:sleep).with(20).once
      expect(database).to have_received(:write_results).once
    end

    it 'raises when the retry also fails' do
      allow(database).to receive(:query).and_raise(query_error)
      allow(described_class).to receive(:sleep)

      expect do
        described_class.query('ybp_vendor.sql', 'results.txt')
      end.to raise_error(query_error)

      expect(database).to have_received(:query).twice
      expect(database).not_to have_received(:write_results)
    end
  end
end
