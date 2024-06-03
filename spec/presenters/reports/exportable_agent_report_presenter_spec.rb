require 'rails_helper'

RSpec.describe Reports::ExportableAgentReportPresenter do
  let(:account) { create(:account) }
  let(:user1) { create(:user, account: account) }
  let(:user2) { create(:user, account: account) }

  let(:start_date) { '2020-01-01' }
  let(:end_date) { '2020-01-01' }
  let(:report_params) { { since: start_date, until: end_date, group_by: 'day', business_hours: false } }
  let(:agent_reports) do
    {
      user1.name => {
        :report_metric1 => [{ value: 10, timestamp: '1708819200' }],
        :report_metric2 => [{ value: 20, timestamp: '1708819200' }]
      },
      user2.name => {
        :report_metric1 => [{ value: 100, timestamp: '1708819200' }],
        :report_metric2 => [{ value: 200, timestamp: '1708819200' }]
      }
    }
  end

  describe '#csv_rows' do
    before do
      stub_const('V2::ReportBuilder::REPORT_METRICS', %w[report_metric1 report_metric2])
    end

    it 'returns CSV rows for detailed agent report' do
      presenter = described_class.new(agent_reports, report_params)
      allow(presenter).to receive(:timestamp_to_date).and_return('2020-01-01')

      expect(presenter.csv_rows).to eq(
        [
          ['Report Metric1'],
          ['Date', user1.name, user2.name],
          ['2020-01-01', 10, 100],
          [],
          ['Report Metric2'],
          ['Date', user1.name, user2.name],
          ['2020-01-01', 20, 200],
          []
        ]
      )
    end
  end

end
