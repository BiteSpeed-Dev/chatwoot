class WeeklyConversationReportJob < ApplicationJob
  queue_as :scheduled_jobs

  # rubocop:disable Metrics/MethodLength
  def perform
    account_ids = [740] # enabled for ecraft
    end_date = Date.yesterday
    start_date = end_date - 6.days

    account_ids.each do |account_id|
      report = generate_report(account_id, start_date, end_date + 1.day)

      if report.present?
        Rails.logger.info "Data found for account_id: #{account_id}"

        csv_content = generate_csv(report)

        # upload csv_content via ActiveStorage and print the URL
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new(csv_content),
          filename: "weekly_conversation_report_#{account_id}_#{start_date}_to_#{end_date}.csv",
          content_type: 'text/csv'
        )

        csv_url = Rails.application.routes.url_helpers.url_for(blob)

        # send email with the CSV URL
        mailer = AdministratorNotifications::ChannelNotificationsMailer.with(account: Account.find(account_id))
        mailer.weekly_conversation_report(csv_url, start_date, end_date).deliver_now
      else
        Rails.logger.info "No data found for account_id: #{account_id}"
      end
    end
  end

  private

  def generate_report(account_id, start_date, end_date)
    # Using ActiveRecord::Base directly for sanitization
    sql = ActiveRecord::Base.send(:sanitize_sql_array, [<<-SQL.squish, { account_id: account_id, start_date: start_date, end_date: end_date }])
      SELECT
          u.name AS agent_name,
          COUNT(*) AS all,
          SUM(CASE WHEN c.status = 0 THEN 1 ELSE 0 END) AS open,
          SUM(CASE WHEN c.status = 1 THEN 1 ELSE 0 END) AS resolved,
          SUM(CASE WHEN c.status = 2 THEN 1 ELSE 0 END) AS pending,
          SUM(CASE WHEN c.status = 3 THEN 1 ELSE 0 END) AS snoozed
      FROM
          conversations c
      JOIN
          account_users au ON c.assignee_id = au.user_id
      JOIN
          users u ON au.user_id = u.id
      WHERE
          c.account_id = :account_id
          AND c.updated_at >= :start_date AND c.updated_at < :end_date
      GROUP BY
          u.name
      ORDER BY
          u.name
    SQL

    ActiveRecord::Base.connection.exec_query(sql)
  end
  # rubocop:enable Metrics/MethodLength

  def generate_csv(results)
    CSV.generate(headers: true) do |csv|
      csv << ['Agent Name', 'Total', 'Open', 'Resolved', 'Pending', 'Snoozed']
      results.each do |row|
        csv << [row['agent_name'], row['all'], row['open'], row['resolved'], row['pending'], row['snoozed']]
      end
    end
  end
end
