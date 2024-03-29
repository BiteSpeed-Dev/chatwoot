class V2::Reports::Agents::ResolutionsCountBuilder < V2::Reports::Agents::BaseReportBuilder
  def perform
    agents.map do |agent|
      {
        id: agent.id,
        name: agent.name,
        email: agent.email,
        entries: resolutions_count_by_user[agent.id]
      }
    end
  end

  private

  def resolutions
    @resolutions ||= account.reporting_events.joins(:conversation)
                            .select(:conversation_id)
                            .where(name: :conversation_resolved, conversations: { status: :resolved })
                            .group(:user_id) # group by agent on reporting events
  end

  def grouped_resolutions_count
    (get_grouped_values resolutions).count
  end

  ## pulling out agent_user_id from: [[agent_user_id, group_by], resolutions_count]
  def agent_user_id_key(grouped_result)
    grouped_result.first.first
  end

  ## pulling out resolutions_count from: [[agent_user_id, group_by], resolutions_count]
  def resolutions_count(grouped_result)
    grouped_result.second
  end

  ## pulling out group_by from: [[agent_user_id, group_by], resolutions_count]
  def group_by_duration_key(grouped_result)
    grouped_result.first.second
  end

  def resolutions_count_by_user
    @resolutions_count_by_user ||= grouped_resolutions_count.each_with_object({}) do |result, hash|
      hash[agent_user_id_key(result)] ||= {}
      hash[agent_user_id_key(result)][group_by_duration_key(result)] = resolutions_count(result)
    end
  end
end
