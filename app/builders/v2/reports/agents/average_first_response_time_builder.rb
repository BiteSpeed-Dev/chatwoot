class V2::Reports::Agents::AverageFirstResponseTimeBuilder
  include DateRangeHelper

  pattr_initialize [:account, :business_hours, :since, :until]

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
    @reporting_events ||= account.reporting_events.where(created_at: range)
  end

  def grouped_average_first_response
    value_attribute = business_hours ? 'value_in_business_hours' : 'value'
    reporting_events.where(name: 'first_response')
                    .where.not(user_id: nil)
                    .select("DATE(created_at) as created_date, user_id, AVG(#{value_attribute}) as avg_first_response")
                    .group('created_date, user_id')
                    .order('created_date ASC')
  end

  def average_first_response_by_date_user
    @average_first_response_by_date_user ||= grouped_average_first_response.each_with_object({}) do |result, hash|
      hash[result.user_id] ||= {}
      hash[result.user_id][result.created_at] = result.average_value
    end
  end

  def agents
    @agents ||= account.users.order_by_full_name
  end
end
