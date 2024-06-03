class Reports::GenerateDetailedAgentReportsJob < ApplicationJob
  queue_as :default

  def perform(account_id, report_params)
    account = Account.find(account_id)
    agent_reports = generate_detailed_agent_reports_for_account(account, report_params)
    start_date = report_params[:since]
    end_date = report_params[:until]
    csv_file = generate_csv(agent_reports, report_params, start_date, end_date)
    AdministratorNotifications::DetailedAgentReportsMailer
      .with(account: account)
      .agent_report(Date.strptime(start_date, '%s'), Date.strptime(end_date, '%s'), csv_file, report_params[:email])
      &.deliver_later
  end

  private

  def generate_csv(agent_reports, report_params, start_date, end_date)
    CSV.generate do |csv|
      csv.puts ["Detailed agents report from: #{Date.strptime(start_date, '%s')} to: #{Date.strptime(end_date, '%s')}"]
      csv.puts []
      Reports::ExportableAgentReportPresenter.new(agent_reports, report_params).csv_rows.each do |row|
        csv << row
      end
    end
  end

  def generate_detailed_report_for_agent(account, report_params)
    V2::ReportBuilder.new(account, report_params).detailed_report
  end

  def generate_detailed_agent_reports_for_account(account, report_params)
    account.users.each_with_object({}) do |agent, reports|
      reports[agent.name] = generate_detailed_report_for_agent(account, report_params.merge({ type: :agent, id: agent.id }))
    end
  end
end
