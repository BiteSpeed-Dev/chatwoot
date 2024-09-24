class V2::Reports::Agents::ReplyTimeBuilder < V2::Reports::Agents::BaseReportBuilder
  def perform
    agents.map do |agent|
      {
        id: agent.id,
        name: agent.name,
        email: agent.email,
        entries: average_reply_time_by_user[agent.id]
      }
    end
  end

  private

  def reporting_events
    @reporting_events ||= account.reporting_events.where(name: 'reply_time')
                                 .where.not(user_id: nil) # exclude bot responses
                                 .group(:user_id) # group by agent
  end

  def grouped_average_reply_time
    value_attribute = params[:business_hours] ? :value_in_business_hours : :value
    (get_grouped_values reporting_events).average(value_attribute) # uses groupdate gem to group by custom time periods
  end

  ## pulling out agent_user_id from: [[agent_user_id, group_by], average_reply_time_value]
  def agent_user_id_key(grouped_result)
    grouped_result.first.first
  end

  ## pulling out average_reply_time_value from: [[agent_user_id, group_by], average_reply_time_value]
  def average_reply_time_value(grouped_result)
    grouped_result.second
  end

  ## pulling out group_by from: [[agent_user_id, group_by], average_reply_time_value]
  def group_by_duration_key(grouped_result)
    grouped_result.first.second
  end

  def average_reply_time_by_user
    @average_reply_time_by_user ||= grouped_average_reply_time.each_with_object({}) do |result, hash|
      hash[agent_user_id_key(result)] ||= {}
      hash[agent_user_id_key(result)][group_by_duration_key(result)] = average_reply_time_value(result)
    end
  end
end
