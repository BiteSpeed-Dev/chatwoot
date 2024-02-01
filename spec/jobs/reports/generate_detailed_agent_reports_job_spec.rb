require 'rails_helper'

RSpec.describe Reports::GenerateDetailedAgentReportsJob, type: :job do
  let(:account) { create(:account) }
  let(:user1) { create(:user, account: account) }
  let(:user2) { create(:user, account: account) }

  let(:start_date) { 1.day.ago }
  let(:end_date) { Time.now }

  it 'enqueues the job' do
    expect { described_class.perform_later(account.id, {}) }.to have_enqueued_job(described_class)
      .on_queue('default')
  end

  context 'when perform' do
    let(:report_params) { { since: start_date.to_s, until: end_date.to_s, group_by: 'day', business_hours: false } }
    let(:job) { described_class.perform_now(account.id, report_params) }

    it 'generates detailed agent reports for each agent belonging to account' do
      allow(account).to receive(:users).and_return([user1, user2])
      allow(V2::ReportBuilder).to receive(:new).and_return(report_builder = double)
      allow(report_builder).to receive(:detailed_report).and_return('report')

      allow(Reports::ExportableAgentReportPresenter).to receive(:new).and_return(presenter = double)
      allow(presenter).to receive(:csv_rows).and_return([['row1'], ['row2']])

      job

      expect(report_builder).to have_received(:detailed_report).twice
    end

    it 'generates CSV file using presenter and calls mailer' do
      allow(Reports::ExportableAgentReportPresenter).to receive(:new).and_return(presenter = double)
      allow(presenter).to receive(:csv_rows).and_return([['row1'], ['row2']])

      allow(AdministratorNotifications::DetailedAgentReportsMailer).to receive(:with).with(account: account).and_return(mailer = double)
      allow(mailer).to receive(:agent_report)

      job

      expect(presenter).to have_received(:csv_rows)
      expect(mailer).to have_received(:agent_report)
    end
  end

end
