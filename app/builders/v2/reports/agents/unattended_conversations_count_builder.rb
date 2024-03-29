class V2::Reports::Agents::UnattendedConversationsCountBuilder < V2::Reports::Agents::BaseReportBuilder
  def perform
    agents.map do |agent|
      {
        id: agent.id,
        name: agent.name,
        email: agent.email,
        entries: unattended_conversations_count_by_user[agent.id]
      }
    end
  end

  private

  def unattended_conversations
    @unattended_conversations ||= account.conversations.open.unattended
                                         .where.not(assignee_id: nil)
                                         .group(:assignee_id) # group by agent

  end

  def grouped_unattended_conversations_count
    (get_grouped_values unattended_conversations).count
  end

  ## pulling out agent_user_id from: [[agent_user_id, group_by], unattended_conversations_count]
  def agent_user_id_key(grouped_result)
    grouped_result.first.first
  end

  ## pulling out unattended_conversations_count from: [[agent_user_id, group_by], unattended_conversations_count]
  def unattended_conversations_count(grouped_result)
    grouped_result.second
  end

  ## pulling out group_by from: [[agent_user_id, group_by], unattended_conversations_count]
  def group_by_duration_key(grouped_result)
    grouped_result.first.second
  end

  def unattended_conversations_count_by_user
    @unattended_conversations_count_by_user ||= grouped_unattended_conversations_count.each_with_object({}) do |result, hash|
      hash[agent_user_id_key(result)] ||= {}
      hash[agent_user_id_key(result)][group_by_duration_key(result)] = unattended_conversations_count(result)
    end
  end
end
