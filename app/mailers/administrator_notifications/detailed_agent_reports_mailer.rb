class AdministratorNotifications::DetailedAgentReportsMailer < ApplicationMailer
  def agent_report(start_date, end_date, csv_file, email_to)
    return unless smtp_config_set_or_development?

    subject = "Detailed agents report from: #{start_date} to: #{end_date}"
    file_name = "detailed_agents_report_#{start_date}_to_#{end_date}.csv"
    attachments[file_name] = csv_file
    send_mail_with_liquid(to: email_to, subject: subject) and return
  end
end
