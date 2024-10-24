# rubocop:disable Metrics/ModuleLength
# rubocop:disable Metrics/AbcSize
# rubocop:disable Layout/LineLength
# rubocop:disable Metrics/MethodLength
# rubocop:disable Rails/HelperInstanceVariable
# rubocop:disable Metrics/CyclomaticComplexity
module CustomReportHelper
  include OnlineStatusHelper

  private

  ### Conversation Statuses Metrics ###
  def new_assigned
    # New conversations assigned in the given time period
    base_query = @account.conversations.where(account_id: account.id, created_at: @time_range)

    base_query = label_filtered_conversations if @config[:filters][:labels].present?
    base_query = base_query.where(inbox_id: @config[:filters][:inboxes]) if @config[:filters][:inboxes].present?
    base_query = base_query.where(assignee_id: @config[:filters][:agents]) if @config[:filters][:agents].present?
    group_and_count(base_query, @config[:group_by])
  end

  def carry_forwarded
    # conversations that were created before the start of the specified time period, but are still not resolved at the start of specified time period
    not_resolved_conversations_before_time_range = ConversationStatus.from(
      "(#{latest_conversation_statuses_before_time_range.to_sql}) AS conversation_statuses"
    ).where.not(status: :resolved)

    base_query = @account.conversations.where(id: not_resolved_conversations_before_time_range.pluck(:conversation_id))

    if @config[:filters][:labels].present?
      base_query = label_filtered_conversations.where(id: not_resolved_conversations_before_time_range.pluck(:conversation_id))
    end
    base_query = base_query.where(inbox_id: @config[:filters][:inboxes]) if @config[:filters][:inboxes].present?
    base_query = base_query.where(assignee_id: @config[:filters][:agents]) if @config[:filters][:agents].present?

    group_and_count(base_query, @config[:group_by])
  end

  def reopened
    # conversations that reverted to an open state from resolved state(any other state doesnt count) during the specified time period.
    resolved_conversations_before_time_range = ConversationStatus.from("(#{latest_conversation_statuses_before_time_range.to_sql}) AS conversation_statuses").where(status: :resolved)

    reopened_conversations = first_conversation_statuses.where(conversation_id: resolved_conversations_before_time_range.pluck(:conversation_id)).where(status: :open)

    base_query = @account.conversations.where(id: reopened_conversations.pluck(:id))

    base_query = label_filtered_conversations.where(id: reopened_conversations.pluck(:id)) if @config[:filters][:labels].present?
    base_query = base_query.where(inbox_id: @config[:filters][:inboxes]) if @config[:filters][:inboxes].present?
    base_query = base_query.where(assignee_id: @config[:filters][:agents]) if @config[:filters][:agents].present?

    group_and_count(base_query, @config[:group_by])
  end

  def handled
    # carry forwarded + new assigned + reopened
    if @config[:group_by].present?
      # For grouped data, we need to merge the results
      result = {}
      [carry_forwarded, new_assigned, reopened].each do |data|
        data.each do |key, value|
          result[key] ||= 0
          result[key] += value
        end
      end
      result
    else
      # For non-grouped data, we can simply sum the values
      carry_forwarded + new_assigned + reopened
    end
  end

  def open
    # conversations that remain in an “Open” state at the end of the specified period.
    open_conversations = ConversationStatus.from("(#{latest_conversation_statuses.to_sql}) AS conversation_statuses").where(status: :open)

    base_query = @account.conversations.where(id: open_conversations.pluck(:conversation_id))

    base_query = label_filtered_conversations.where(id: open_conversations.pluck(:conversation_id)) if @config[:filters][:labels].present?
    base_query = base_query.where(inbox_id: @config[:filters][:inboxes]) if @config[:filters][:inboxes].present?
    base_query = base_query.where(assignee_id: @config[:filters][:agents]) if @config[:filters][:agents].present?
    group_and_count(base_query, @config[:group_by])
  end

  def resolved
    # conversations that get resolved at the end of the specified period.
    resolved_conversations = ConversationStatus.from("(#{latest_conversation_statuses.to_sql}) AS conversation_statuses").where(status: :resolved)

    base_query = @account.conversations.where(id: resolved_conversations.pluck(:conversation_id))

    Rails.logger.info "ljaksdflk #{@config}"

    base_query = label_filtered_conversations.where(id: resolved_conversations.pluck(:conversation_id)) if @config[:filters][:labels].present?
    base_query = base_query.where(inbox_id: @config[:filters][:inboxes]) if @config[:filters][:inboxes].present?
    base_query = base_query.where(assignee_id: @config[:filters][:agents]) if @config[:filters][:agents].present?
    group_and_count(base_query, @config[:group_by])
  end

  def snoozed
    # conversations that remain in an “Snoozed” state at the end of the specified period.
    snoozed_conversations = ConversationStatus.from("(#{latest_conversation_statuses.to_sql}) AS conversation_statuses").where(status: :snoozed)

    base_query = @account.conversations.where(id: snoozed_conversations.pluck(:conversation_id))

    base_query = label_filtered_conversations.where(id: snoozed_conversations.pluck(:conversation_id)) if @config[:filters][:labels].present?
    base_query = base_query.where(inbox_id: @config[:filters][:inboxes]) if @config[:filters][:inboxes].present?
    base_query = base_query.where(assignee_id: @config[:filters][:agents]) if @config[:filters][:agents].present?

    group_and_count(base_query, @config[:group_by])
  end

  def waiting_agent_response
    # conversations that are open and waiting an agent response at the end of the specified period.

    open_conversations = ConversationStatus.from("(#{latest_conversation_statuses.to_sql}) AS conversation_statuses").where(status: :open)

    conversation_waiting_agent_response = Message.from("(#{latest_messages(open_conversations.pluck(:conversation_id)).to_sql}) AS messages").where(message_type: :incoming)

    Rails.logger.info "conversation_waiting_agent_response: #{conversation_waiting_agent_response.to_sql}"

    base_query = @account.conversations.where(id: conversation_waiting_agent_response.pluck(:conversation_id))

    if @config[:filters][:labels].present?
      base_query = label_filtered_conversations.where(id: conversation_waiting_agent_response.pluck(:conversation_id))
    end
    base_query = base_query.where(inbox_id: @config[:filters][:inboxes]) if @config[:filters][:inboxes].present?
    base_query = base_query.where(assignee_id: @config[:filters][:agents]) if @config[:filters][:agents].present?

    group_and_count(base_query, @config[:group_by])
  end

  def waiting_customer_response
    # conversations that are open and waiting a customer response at the end of the specified period.

    open_conversations = ConversationStatus.from("(#{latest_conversation_statuses.to_sql}) AS conversation_statuses").where(status: :open)

    conversation_waiting_customer_response = Message.from(latest_messages(open_conversations.pluck(:conversation_id))).where(message_type: [
                                                                                                                               :outgoing, :template
                                                                                                                             ])

    base_query = @account.conversations.where(id: conversation_waiting_customer_response.pluck(:conversation_id))

    if @config[:filters][:labels].present?
      base_query = label_filtered_conversations.where(id: conversation_waiting_customer_response.pluck(:conversation_id))
    end
    base_query = base_query.where(inbox_id: @config[:filters][:inboxes]) if @config[:filters][:inboxes].present?
    base_query = base_query.where(assignee_id: @config[:filters][:agents]) if @config[:filters][:agents].present?

    group_and_count(base_query, @config[:group_by])
  end

  ### Agent Metrics ###
  def avg_first_response_time
    # the average time elapsed between a ticket getting assigned to an agent and the agent responding to it for the first time.
    base_query = @account.reporting_events.where(name: 'first_response', created_at: @time_range)

    base_query = base_query.where(conversation_id: label_filtered_conversations.pluck(:id)) if @config[:filters][:labels].present?
    base_query = base_query.where(inbox_id: @config[:filters][:inboxes]) if @config[:filters][:inboxes].present?
    base_query = base_query.where(user_id: @config[:filters][:agents]) if @config[:filters][:agents].present?

    Rails.logger.info "Base query(avg_first_response_time): #{base_query.to_sql}"

    Rails.logger.info "get_grouped_average(base_query) #{get_grouped_average(base_query)}"

    get_grouped_average(base_query)
  end

  def avg_resolution_time
    # the average time elapsed between a ticket getting assigned to an agent and the agent sending the last message to the customer (only resolved tickets are included in this calculation)
    base_query = @account.reporting_events.where(name: 'conversation_resolved', created_at: @time_range)

    base_query = base_query.where(conversation_id: label_filtered_conversations.pluck(:id)) if @config[:filters][:labels].present?
    base_query = base_query.where(inbox_id: @config[:filters][:inboxes]) if @config[:filters][:inboxes].present?
    base_query = base_query.where(user_id: @config[:filters][:agents]) if @config[:filters][:agents].present?

    get_grouped_average(base_query)
  end

  def avg_response_time
    # the average time elapsed b/w a cx messaging and agent replying during the whole conversation
    base_query = @account.reporting_events.where(name: 'reply_time', created_at: @time_range)

    base_query = base_query.where(conversation_id: label_filtered_conversations.pluck(:id)) if @config[:filters][:labels].present?
    base_query = base_query.where(inbox_id: @config[:filters][:inboxes]) if @config[:filters][:inboxes].present?
    base_query = base_query.where(user_id: @config[:filters][:agents]) if @config[:filters][:agents].present?

    get_grouped_average(base_query)
  end

  def avg_csat_score
    # Score given by cx at the end of each conversation resolution
    base_query = @account.csat_survey_responses.where(created_at: @time_range)

    base_query = base_query.where(conversation_id: label_filtered_conversations.pluck(:id)) if @config[:filters][:labels].present?
    base_query = base_query.filter_by_inbox_id(@config[:filters][:inboxes]) if @config[:filters][:inboxes].present?
    base_query = base_query.filter_by_assigned_agent_id(@config[:filters][:agents]) if @config[:filters][:agents].present?

    get_grouped_average_csat(base_query)
  end

  def median_first_response_time
    # the median time elapsed between a ticket getting assigned to an agent and the agent responding to it for the first time.
    base_query = @account.reporting_events.where(name: 'first_response', created_at: @time_range)

    base_query = base_query.where(conversation_id: label_filtered_conversations.pluck(:id)) if @config[:filters][:labels].present?
    base_query = base_query.where(inbox_id: @config[:filters][:inboxes]) if @config[:filters][:inboxes].present?
    base_query = base_query.where(user_id: @config[:filters][:agents]) if @config[:filters][:agents].present?

    get_grouped_median(base_query)
  end

  def median_resolution_time
    # the median time elapsed between a ticket getting assigned to an agent and the agent sending the last message to the customer (only resolved tickets are included in this calculation)
    base_query = @account.reporting_events.where(name: 'conversation_resolved', created_at: @time_range)

    base_query = base_query.where(conversation_id: label_filtered_conversations.pluck(:id)) if @config[:filters][:labels].present?
    base_query = base_query.where(inbox_id: @config[:filters][:inboxes]) if @config[:filters][:inboxes].present?
    base_query = base_query.where(user_id: @config[:filters][:agents]) if @config[:filters][:agents].present?

    get_grouped_median(base_query)
  end

  def median_response_time
    # the median time elapsed b/w a cx messaging and agent replying during the whole conversation
    base_query = @account.reporting_events.where(name: 'reply_time', created_at: @time_range)

    base_query = base_query.where(conversation_id: label_filtered_conversations.pluck(:id)) if @config[:filters][:labels].present?
    base_query = base_query.where(inbox_id: @config[:filters][:inboxes]) if @config[:filters][:inboxes].present?
    base_query = base_query.where(user_id: @config[:filters][:agents]) if @config[:filters][:agents].present?

    get_grouped_median(base_query)
  end

  def median_csat_score
    # median score given by cx at the end of each conversation resolution
    base_query = @account.csat_survey_responses.where(created_at: @time_range)

    base_query = base_query.where(conversation_id: label_filtered_conversations.pluck(:id)) if @config[:filters][:labels].present?
    base_query = base_query.filter_by_inbox_id(@config[:filters][:inboxes]) if @config[:filters][:inboxes].present?
    base_query = base_query.filter_by_assigned_agent_id(@config[:filters][:agents]) if @config[:filters][:agents].present?
    base_query = base_query.filter_by_team_id(@config[:filters][:teams]) if @config[:filters][:teams].present?

    get_grouped_median_csat(base_query)
  end

  ### Helper Methods ###

  def get_grouped_average(events)
    if @config[:group_by].present?
      events.group(group_by_key).average(average_value_key)
    else
      events.average(average_value_key)
    end
  end

  def get_grouped_median(events)
    if @config[:group_by].present?
      group_key = group_by_key
      value_key = average_value_key

      Rails.logger.info "get_grouped_median Group key: #{group_key.inspect}, Value key: #{value_key.inspect}"

      return {} if group_key.nil? || value_key.nil?

      begin
        result = events.group(group_key)
                       .pluck(Arel.sql(sanitize_sql_for_conditions(["#{group_key}, ARRAY_AGG(#{value_key})"])))
                       .to_h
                       .transform_values { |values| calculate_median(values) }
        Rails.logger.info "Grouped median result: #{result.inspect}"
        result
      rescue ActiveRecord::StatementInvalid => e
        Rails.logger.error "Error in get_grouped_median: #{e.message}"
        {}
      end
    else
      calculate_median(events.pluck(average_value_key))
    end
  end

  def calculate_median(array)
    return nil if array.empty?

    sorted = array.sort
    len = sorted.length
    (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end

  def sanitize_sql_for_conditions(sql)
    ActiveRecord::Base.send(:sanitize_sql_for_conditions, sql)
  end

  def get_grouped_average_csat(events)
    if @config[:group_by].present?
      case @config[:group_by]
      when 'agent'
        events.group(:assigned_agent_id).average(:rating)
      when 'inbox'
        events.joins(:conversation).group('conversations.inbox_id').average(:rating)
      end
    else
      events.average(:rating)
    end
  end

  def get_grouped_median_csat(events)
    if @config[:group_by].present?
      group_key, join_condition = case @config[:group_by]
                                  when 'agent'
                                    [:assigned_agent_id, nil]
                                  when 'inbox'
                                    ['conversations.inbox_id', :conversation]
                                  else
                                    [nil, nil]
                                  end

      Rails.logger.info "CSAT Group key: #{group_key.inspect}, Join condition: #{join_condition.inspect}"

      return {} if group_key.nil?

      begin
        query = join_condition ? events.joins(join_condition) : events
        result = query.group(group_key)
                      .pluck(Arel.sql(sanitize_sql_for_conditions(["#{group_key}, ARRAY_AGG(rating)"])))
                      .to_h
                      .transform_values { |ratings| calculate_median(ratings) }
        Rails.logger.info "Grouped median CSAT result: #{result.inspect}"
        result
      rescue ActiveRecord::StatementInvalid => e
        Rails.logger.error "Error in get_grouped_median_csat: #{e.message}"
        {}
      end
    else
      calculate_median(events.pluck(:rating))
    end
  end

  def average_value_key
    @config[:filters][:business_hours].present? && @config[:filters][:business_hours] == true ? :value_in_business_hours : :value
  end

  def group_by_key
    case @config[:group_by]
    when 'agent'
      :user_id
    when 'inbox'
      :inbox_id
    end
  end

  def group_and_count(query, group_by_param)
    case group_by_param
    when 'agent'
      query.group(:assignee_id).count
    when 'inbox'
      query.group(:inbox_id).count
    else
      query.count
    end
  end

  def first_conversation_statuses
    ConversationStatus.select('DISTINCT ON (conversation_id) conversation_id, status, created_at').where(
      account_id: account.id,
      created_at: @time_range
    ).order('conversation_id, created_at ASC')
  end

  def latest_conversation_statuses
    ConversationStatus.select('DISTINCT ON (conversation_id) conversation_id, status, created_at').where(
      account_id: account.id,
      created_at: @time_range
    ).order('conversation_id, created_at DESC')
  end

  def latest_conversation_statuses_before_time_range
    ConversationStatus.select('DISTINCT ON (conversation_id) conversation_id, status, created_at').where(
      account_id: account.id
    ).where('created_at < ?', @time_range.begin).order('conversation_id, created_at DESC')
  end

  def latest_messages(conversation_ids)
    Message.select('DISTINCT ON (conversation_id) conversation_id, id, message_type, created_at')
           .where(conversation_id: conversation_ids, created_at: @time_range)
           .where.not(message_type: :activity)
           .order('conversation_id, created_at DESC')
  end

  def label_filtered_conversations
    convs = @account.conversations.tagged_with(@config[:filters][:labels], :any => true).where(created_at: @time_range)
    Rails.logger.info "label_filtered_conversations: #{convs.to_sql}"
    convs
  end
end
# rubocop:enable Metrics/ModuleLength
# rubocop:enable Metrics/AbcSize
# rubocop:enable Layout/LineLength
# rubocop:enable Metrics/MethodLength
# rubocop:enable Metrics/CyclomaticComplexity
# rubocop:enable Rails/HelperInstanceVariable
