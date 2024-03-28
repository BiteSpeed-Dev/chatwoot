class V2::Reports::Agents::ConversationsCountBuilder < V2::Reports::Agents::BaseReportBuilder
  def perform
    agents.map do |agent|
      {
        id: agent.id,
        name: agent.name,
        email: agent.email,
        entries: conversations_count_by_user[agent.id]
      }
    end
  end

  private

  def conversations
    @conversations ||= account.conversations
                              .where.not(assignee_id: nil) # exclude bot responses
                              .group(:assignee_id) # group by agent
  end

  def grouped_conversations_count
    (get_grouped_values conversations).count
  end

  ## pulling out agent_user_id from: [[agent_user_id, group_by], conversations_count]
  def agent_user_id_key(grouped_result)
    grouped_result.first.first
  end

  ## pulling out conversations_count from: [[agent_user_id, group_by], conversations_count]
  def conversations_count(grouped_result)
    grouped_result.second
  end

  ## pulling out group_by from: [[agent_user_id, group_by], conversations_count]
  def group_by_duration_key(grouped_result)
    grouped_result.first.second
  end

  def conversations_count_by_user
    @conversations_count_by_user ||= grouped_conversations_count.each_with_object({}) do |result, hash|
      hash[agent_user_id_key(result)] ||= {}
      hash[agent_user_id_key(result)][group_by_duration_key(result)] = conversations_count(result)
    end
  end
end
