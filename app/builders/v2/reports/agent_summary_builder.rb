class V2::Reports::AgentSummaryBuilder < V2::Reports::BaseSummaryBuilder
  pattr_initialize [:account!, :params!]

  def build
    set_grouped_conversations_count
    set_grouped_resolved_conversations_count
    set_grouped_avg_reply_time
    set_grouped_avg_first_response_time
    set_grouped_avg_resolution_time
    set_grouped_online_time
    set_grouped_busy_time
    prepare_report
  end

  private

  def set_grouped_conversations_count
    @grouped_conversations_count = Current.account.conversations.where(created_at: range).group('assignee_id').count
  end

  def set_grouped_avg_resolution_time
    @grouped_avg_resolution_time = get_grouped_average(reporting_events.where(name: 'conversation_resolved'))
  end

  def set_grouped_avg_first_response_time
    @grouped_avg_first_response_time = get_grouped_average(reporting_events.where(name: 'first_response'))
  end

  def set_grouped_avg_reply_time
    @grouped_avg_reply_time = get_grouped_average(reporting_events.where(name: 'reply_time'))
  end

  def set_grouped_online_time
    @grouped_online_time = get_grouped_status_time('online')
  end

  def set_grouped_busy_time
    @grouped_busy_time = get_grouped_status_time('busy')
  end

  def set_grouped_resolved_conversations_count
    @grouped_resolved_conversations_count = reporting_events.where(name: 'conversation_resolved').group(group_by_key).count
  end

  def group_by_key
    :user_id
  end

  def reporting_events
    @reporting_events ||= Current.account.reporting_events.where(created_at: range)
  end

  def users_ids
    Current.account.users.pluck(:id)
  end

  def audit_logs
    @audit_logs ||= Audited::Audit.where(user_id: users_ids)
                                  .where(created_at: range)
                                  .where(auditable_type: 'AccountUser')
                                  .where(action: 'update')
  end

  def get_grouped_status_time(status)
    status_value = map_status_to_value(status)
    grouped_time = Hash.new(0)

    users_ids.each do |user_id|
      user_logs = fetch_audit_logs_for_user(user_id)
      next if user_logs.empty?

      grouped_time[user_id] = calculate_time_for_status(user_logs, status_value)
    end

    grouped_time
  end

  def map_status_to_value(status)
    { online: 0, offline: 1, busy: 2 }[status.to_sym]
  end

  def fetch_audit_logs_for_user(user_id)
    audit_logs.where(user_id: user_id).order(:created_at)
  end

  def calculate_time_for_status(user_logs, status_value)
    last_status = nil
    last_time = nil
    total_time = 0

    user_logs.each do |log|
      changes = extract_availability_changes(log)
      next unless changes

      current_status = changes[1]

      # the time calculated here is between when desired status is the current status and when it changes to another status
      total_time += calculate_time_difference(last_status, status_value, last_time, log.created_at)

      last_status, last_time = update_last_status_and_time(current_status, status_value, log.created_at, last_status)
    end

    # calculate the remaining time when last status is the desired status
    total_time += calculate_remaining_time(last_status, status_value, last_time)
    total_time
  end

  def extract_availability_changes(log)
    log.audited_changes['availability']
  end

  def calculate_time_difference(last_status, status_value, last_time, current_time)
    last_status == status_value && last_time ? current_time - last_time : 0
  end

  def update_last_status_and_time(current_status, status_value, current_time, _last_status)
    if current_status == status_value
      [current_status, current_time]
    else
      [current_status, nil]
    end
  end

  def calculate_remaining_time(last_status, status_value, last_time)
    last_status == status_value && last_time ? Time.current - last_time : 0
  end

  def prepare_report
    account.account_users.each_with_object([]) do |account_user, arr|
      user_id = account_user.user_id
      arr << {
        id: user_id,
        conversations_count: @grouped_conversations_count[user_id],
        resolved_conversations_count: @grouped_resolved_conversations_count[user_id],
        avg_resolution_time: @grouped_avg_resolution_time[user_id],
        avg_first_response_time: @grouped_avg_first_response_time[user_id],
        avg_reply_time: @grouped_avg_reply_time[user_id],
        online_time: @grouped_online_time[user_id],
        busy_time: @grouped_busy_time[user_id]
      }
    end
  end

  def average_value_key
    ActiveModel::Type::Boolean.new.cast(params[:business_hours]).present? ? :value_in_business_hours : :value
  end
end
