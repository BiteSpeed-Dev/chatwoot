require 'rails_helper'

RSpec.describe V2::Reports::Agents::AverageFirstResponseTimeBuilder do
  describe '#perform' do
    subject { builder.perform }

    let(:account) { create(:account) }
    let(:business_hours) { false }
    let(:since) { 1.month.ago }
    let(:untill) { Time.zone.now }
    let(:builder) { described_class.new(account: account, business_hours: business_hours, since: since, until: untill) }

    it 'returns the average first response time by agent' do
      expect(subject).to eq([])
    end
  end
end
