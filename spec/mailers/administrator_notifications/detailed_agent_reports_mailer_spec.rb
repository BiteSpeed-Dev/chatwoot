
require "rails_helper"

RSpec.describe AdministratorNotifications::DetailedAgentReportsMailer, type: :mailer do
  let(:class_instance) { described_class.new }
  let!(:account) { create(:account) }
  let!(:report_creator) { create(:user, :administrator, email: 'agent1@example.com', account: account) }

  before do
    allow(described_class).to receive(:new).and_return(class_instance)
    allow(class_instance).to receive(:smtp_config_set_or_development?).and_return(true)
  end

  describe 'agent_report' do
    csv_file = CSV.generate{|csv| csv << ['Detailed report']}
    let(:start_date) { '2020-01-01' }
    let(:end_date) { '2020-01-02' }
    let(:mail) { described_class.with(account: account).agent_report(start_date, end_date, csv_file, report_creator.email).deliver_now }

    it 'renders the subject' do
      expect(mail.subject).to eq("Detailed agents report from: #{start_date} to: #{end_date}")
    end

    it 'renders the receiver email' do
      expect(mail.to).to eq([report_creator.email])
    end

    it 'renders the content' do
      expect(mail.body.encoded).to include('Your detailed agent report file is attached.')
    end

    it 'renders the attachment' do
      expect(mail.attachments["detailed_agents_report_#{start_date}_to_#{end_date}.csv"]).to be_present
    end
  end
end
