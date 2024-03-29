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
      :report_metric1 => [
        {
          id: user1.id,
          name: user1.name,
          email: user1.email,
          entries: { '2020-01-01' => 10 }
        },
        {
          id: user2.id,
          name: user2.name,
          email: user2.email,
          entries: { '2020-01-01' => 100 }
        }
      ],
      :report_metric2 => [
        {
          id: user1.id,
          name: user1.name,
          email: user1.email,
          entries: { '2020-01-01' => 20 }
        },
        {
          id: user2.id,
          name: user2.name,
          email: user2.email,
          entries: { '2020-01-01' => 200 }
        }
      ]
    }
  end

  describe '#csv_rows' do
    before do
      stub_const('V2::ReportBuilder::REPORT_METRICS', %w[report_metric1 report_metric2])
    end

    it 'returns CSV rows for detailed agent report' do
      presenter = described_class.new(agent_reports, report_params)
      # allow(presenter).to receive(:timestamp_to_date).and_return('2020-01-01')

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
