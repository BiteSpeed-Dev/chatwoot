module ReportSummaryMetricsHelper
  private

  def avg_resolution_time_summary
    reporting_events = scope.reporting_events
                            .where(name: 'conversation_resolved', account_id: account.id, created_at: range)
                            .tap do |s|
                              s.where!(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
                            end
    avg_rt = if params[:business_hours].present?
               reporting_events.average(:value_in_business_hours)
             else
               reporting_events.average(:value)
             end

    return 0 if avg_rt.blank?

    avg_rt
  end

  def reply_time_summary
    reporting_events = scope.reporting_events
                            .where(name: 'reply_time', account_id: account.id, created_at: range)
                            .tap do |s|
                              s.where!(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
                            end
    reply_time = params[:business_hours] ? reporting_events.average(:value_in_business_hours) : reporting_events.average(:value)

    return 0 if reply_time.blank?

    reply_time
  end

  def avg_first_response_time_summary
    reporting_events = scope.reporting_events
                            .where(name: 'first_response', account_id: account.id, created_at: range)
                            .tap do |s|
                              s.where!(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
                            end
    avg_frt = if params[:business_hours].present?
                reporting_events.average(:value_in_business_hours)
              else
                reporting_events.average(:value)
              end

    return 0 if avg_frt.blank?

    avg_frt
  end
end
