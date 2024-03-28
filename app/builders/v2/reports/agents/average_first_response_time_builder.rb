class V2::Reports::Agents::AverageFirstResponseTimeBuilder < V2::Reports::Agents::BaseReportBuilder
  def perform
    agents.map do |agent|
      {
        id: agent.id,
        name: agent.name,
        email: agent.email,
        entries: average_first_response_by_date_user[agent.id]
      }
    end
  end

  private

  def reporting_events
    @reporting_events ||= account.reporting_events.where(name: 'first_response')
                                 .where.not(user_id: nil) # exclude bot responses
                                 .group(:user_id) # group by agent
  end

  def grouped_average_first_response
    value_attribute = params[:business_hours] ? :value_in_business_hours : :value
    (get_grouped_values reporting_events).average(value_attribute) # uses groupdate gem to group by custom time periods
  end

  ## pulling out agent_user_id from: [[agent_user_id, group_by], average_first_response_value]
  def agent_user_id_key(grouped_result)
    grouped_result.first.first
  end

  ## pulling out average_first_response_value from: [[agent_user_id, group_by], average_first_response_value]
  def average_first_response_value(grouped_result)
    grouped_result.second
  end

  ## pulling out group_by from: [[agent_user_id, group_by], average_first_response_value]
  def group_by_duration_key(grouped_result)
    grouped_result.first.second
  end

  def average_first_response_by_date_user
    @average_first_response_by_date_user ||= grouped_average_first_response.each_with_object({}) do |result, hash|
      hash[agent_user_id_key(result)] ||= {}
      hash[agent_user_id_key(result)][group_by_duration_key(result)] = average_first_response_value(result)
    end
  end

  def agents
    @agents ||= account.users.order_by_full_name
  end
end
