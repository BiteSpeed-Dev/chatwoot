# rubocop:disable Metrics/ModuleLength
module ReportHelper
  include OnlineStatusHelper

  private

  def scope
    case params[:type]
    when :account
      account
    when :inbox
      inbox
    when :agent
      user
    when :label
      label
    when :team
      team
    end
  end

  def conversations_count
    (get_grouped_values conversations).count
  end

  def incoming_messages_count
    (get_grouped_values incoming_messages).count
  end

  def outgoing_messages_count
    (get_grouped_values outgoing_messages).count
  end

  def resolutions_count
    (get_grouped_values resolutions).count
  end

  def bot_resolutions_count
    (get_grouped_values bot_resolutions).count
  end

  def bot_handoffs_count
    (get_grouped_values bot_handoffs).count
  end

  def conversations
    # TODO: [P0] fix why numbers not visible in the report
    if params[:label].present?
      filtered_converstations = scope.conversations.where(account_id: account.id, created_at: range)
      filtered_converstations.tagged_with([params[:label]], any: true)

    else
      scope.conversations.where(account_id: account.id, created_at: range)
    end
  end

  def incoming_messages
    scope.messages.where(account_id: account.id, created_at: range).incoming.unscope(:order)
  end

  def outgoing_messages
    scope.messages.where(account_id: account.id, created_at: range).outgoing.unscope(:order)
  end

  def resolutions
    scope.reporting_events.joins(:conversation).select(:conversation_id).where(account_id: account.id, name: :conversation_resolved,
                                                                               conversations: { status: :resolved }, created_at: range).distinct
  end

  def bot_resolutions
    scope.reporting_events.joins(:conversation).select(:conversation_id).where(account_id: account.id, name: :conversation_bot_resolved,
                                                                               conversations: { status: :resolved }, created_at: range).distinct
  end

  def bot_handoffs
    scope.reporting_events.joins(:conversation).select(:conversation_id).where(account_id: account.id, name: :conversation_bot_handoff,
                                                                               created_at: range).distinct
  end

  def avg_first_response_time
    grouped_reporting_events = (get_grouped_values scope.reporting_events.where(name: 'first_response', account_id: account.id))
    return grouped_reporting_events.average(:value_in_business_hours) if params[:business_hours]

    grouped_reporting_events.average(:value)
  end

  def reply_time
    grouped_reporting_events = (get_grouped_values scope.reporting_events.where(name: 'reply_time', account_id: account.id))
    return grouped_reporting_events.average(:value_in_business_hours) if params[:business_hours]

    grouped_reporting_events.average(:value)
  end

  def avg_resolution_time
    grouped_reporting_events = (get_grouped_values scope.reporting_events.where(name: 'conversation_resolved', account_id: account.id))
    return grouped_reporting_events.average(:value_in_business_hours) if params[:business_hours]

    grouped_reporting_events.average(:value)
  end

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Layout/LineLength
  def avg_resolution_time_summary
    if params[:label].present?
      label_conversations = scope.conversations.tagged_with(params[:labels], any: true)
      reporting_events = scope.reporting_events
                              .where(name: 'conversation_resolved', account_id: account.id, created_at: range).where(conversation_id: label_conversations.pluck(:id))
    else
      reporting_events = scope.reporting_events
                              .where(name: 'conversation_resolved', account_id: account.id, created_at: range)
    end
    avg_rt = if params[:business_hours].present?
               reporting_events.average(:value_in_business_hours)
             else
               reporting_events.average(:value)
             end

    return 0 if avg_rt.blank?

    avg_rt
  end

  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Layout/LineLength
  def reply_time_summary
    reporting_events = scope.reporting_events
                            .where(name: 'reply_time', account_id: account.id, created_at: range)
    reply_time = params[:business_hours] ? reporting_events.average(:value_in_business_hours) : reporting_events.average(:value)

    return 0 if reply_time.blank?

    reply_time
  end

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Layout/LineLength
  def avg_first_response_time_summary
    if params[:label].present?
      label_conversations = scope.conversations.tagged_with(params[:labels], any: true)
      reporting_events = scope.reporting_events
                              .where(name: 'first_response', account_id: account.id, created_at: range).where(conversation_id: label_conversations.pluck(:id))
    else
      reporting_events = scope.reporting_events
                              .where(name: 'first_response', account_id: account.id, created_at: range)
    end
    avg_frt = if params[:business_hours].present?
                reporting_events.average(:value_in_business_hours)
              else
                reporting_events.average(:value)
              end

    return 0 if avg_frt.blank?

    avg_frt
  end
  # rubocop:enable Layout/LineLength
  # rubocop:enable Metrics/AbcSize

  def online_time_summary
    audit_logs = Audited::Audit.where(user_id: scope.id, associated_id: account.id, created_at: range, auditable_type: 'AccountUser',
                                      action: 'update').order(:created_at)

    return 0 if audit_logs.blank?

    ot = calculate_time_for_status(audit_logs, 0)

    return 0 if ot.blank?

    ot
  end

  def busy_time_summary
    audit_logs = Audited::Audit.where(user_id: scope.id, associated_id: account.id, created_at: range, auditable_type: 'AccountUser',
                                      action: 'update').order(:created_at)

    return 0 if audit_logs.blank?

    bt = calculate_time_for_status(audit_logs, 2)

    return 0 if bt.blank?

    bt
  end
end
# rubocop:enable Metrics/ModuleLength
