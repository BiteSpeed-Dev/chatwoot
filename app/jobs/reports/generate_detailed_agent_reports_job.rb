class Reports::GenerateDetailedAgentReportsJob < ApplicationJob
  queue_as :default

  def perform(account_id, report_params)
    account = Account.find(account_id)
    agent_reports = generate_detailed_agent_reports_for_account(account, report_params)
    start_date = report_params[:since]
    end_date = report_p_firstrams[:until]
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

  def generate_detailed_agent_reports_for_account(account, report_params)
    {
      conversations_count: V2::Reports::Agents::ConversationsCountBuilder.new(account: account, params: report_params).perform,
      unattended_conversations_count: V2::Reports::Agents::UnattendedConversationsCountBuilder.new(account: account, params: report_params).perform,
      incoming_messages_count: V2::Reports::Agents::IncomingMessagesCountBuilder.new(account: account, params: report_params).perform,
      outgoing_messages_count: V2::Reports::Agents::OutgoingMessagesCountBuilder.new(account: account, params: report_params).perform,
      avg_first_response_time: V2::Reports::Agents::AverageFirstResponseTimeBuilder.new(account: account, params: report_params).perform,
      avg_resolution_time: V2::Reports::Agents::AverageResolutionTimeBuilder.new(account: account, params: report_params).perform,
      resolutions_count: V2::Reports::Agents::ResolutionsCountBuilder.new(account: account, params: report_params).perform,
      reply_time: V2::Reports::Agents::ReplyTimeBuilder.new(account: account, params: report_params).perform
    }
  end
end
