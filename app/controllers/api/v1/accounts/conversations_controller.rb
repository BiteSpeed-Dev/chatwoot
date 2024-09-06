# rubocop:disable Metrics/ClassLength
class Api::V1::Accounts::ConversationsController < Api::V1::Accounts::BaseController
  include Events::Types
  include DateRangeHelper
  include HmacConcern

  before_action :conversation, except: [:index, :meta, :search, :create, :filter]
  before_action :inbox, :contact, :contact_inbox, only: [:create]

  def index
    result = conversation_finder.perform
    @conversations = result[:conversations]
    @conversations_count = result[:count]
  end

  def meta
    result = conversation_finder.perform
    @conversations_count = result[:count]
  end

  def search
    result = conversation_finder.perform
    @conversations = result[:conversations]
    @conversations_count = result[:count]
  end

  def attachments
    @attachments = @conversation.attachments
  end

  def show; end

  def create
    Rails.logger.info('Starting conversation creation process')
    # previous_messages = fetch_previous_messages if params[:populate_historical_messages] == 'true'

    # ActiveRecord::Base.transaction do
    #   create_conversation_and_initial_message
    #   populate_historical_messages(previous_messages) if params[:populate_historical_messages] == 'true'
    # end

    Rails.logger.info('Completed conversation creation process:')
    # @conversation
    @conversation = find_previous_conversation

    # return success
  end

  def update
    @conversation.update!(permitted_update_params)
  end

  def filter
    result = ::Conversations::FilterService.new(params.permit!, current_user).perform
    @conversations = result[:conversations]
    @conversations_count = result[:count]
  rescue CustomExceptions::CustomFilter::InvalidAttribute,
         CustomExceptions::CustomFilter::InvalidOperator,
         CustomExceptions::CustomFilter::InvalidValue => e
    render_could_not_create_error(e.message)
  end

  def mute
    @conversation.mute!
    head :ok
  end

  def unmute
    @conversation.unmute!
    head :ok
  end

  def transcript
    render json: { error: 'email param missing' }, status: :unprocessable_entity and return if params[:email].blank?

    ConversationReplyMailer.with(account: @conversation.account).conversation_transcript(@conversation, params[:email])&.deliver_later
    head :ok
  end

  def toggle_status
    # FIXME: move this logic into a service object
    if pending_to_open_by_bot?
      @conversation.bot_handoff!
    elsif params[:status].present?
      set_conversation_status
      @status = @conversation.save!
    else
      @status = @conversation.toggle_status
    end
    assign_conversation if should_assign_conversation?
  end

  def pending_to_open_by_bot?
    return false unless Current.user.is_a?(AgentBot)

    @conversation.status == 'pending' && params[:status] == 'open'
  end

  def should_assign_conversation?
    @conversation.status == 'open' && Current.user.is_a?(User) && Current.user&.agent?
  end

  def toggle_priority
    @conversation.toggle_priority(params[:priority])
    head :ok
  end

  def toggle_typing_status
    typing_status_manager = ::Conversations::TypingStatusManager.new(@conversation, current_user, params)
    typing_status_manager.toggle_typing_status
    head :ok
  end

  def update_last_seen
    update_last_seen_on_conversation(DateTime.now.utc, assignee?)
  end

  def unread
    last_incoming_message = @conversation.messages.incoming.last
    last_seen_at = last_incoming_message.created_at - 1.second if last_incoming_message.present?
    update_last_seen_on_conversation(last_seen_at, true)
  end

  def custom_attributes
    @conversation.custom_attributes = params.permit(custom_attributes: {})[:custom_attributes]
    @conversation.save!
  end

  private

  def create_conversation_and_initial_message
    @conversation = ConversationBuilder.new(params: params, contact_inbox: @contact_inbox).perform
    Rails.logger.info("Created new conversation: #{@conversation.id}")

    return if params[:message].blank?

    Messages::MessageBuilder.new(Current.user, @conversation, params[:message]).perform
    Rails.logger.info("Added initial message to conversation: #{@conversation.id}")
  end

  # rubocop:disable Metrics/AbcSize
  def populate_historical_messages(previous_messages)
    Rails.logger.info("Populating historical messages for conversation: #{@conversation.id}")
    previous_messages.each do |message_data|
      new_message = @conversation.messages.create!(message_data[:message_attributes])
      Rails.logger.info("Created historical message: #{new_message.id}")

      message_data[:attachments].each do |attachment_data|
        new_attachment = new_message.attachments.create!(attachment_data[:attributes])
        Rails.logger.info("Created attachment for historical message: #{new_attachment.id}")

        if attachment_data[:active_storage_data]
          ActiveStorage::Attachment.create!(attachment_data[:active_storage_data].merge(record_id: new_attachment.id))
          Rails.logger.info("Created ActiveStorage attachment for historical message attachment: #{new_attachment.id}")
        end
      end
    end
  end
  # rubocop:enable Metrics/AbcSize

  def fetch_previous_messages
    Rails.logger.info('Fetching previous messages')
    previous_conversation = find_previous_conversation

    if previous_conversation.blank?
      Rails.logger.info('No previous conversation found')
      return []
    end

    Rails.logger.info("Found previous conversation: #{previous_conversation.id}")

    messages = fetch_messages(previous_conversation)
    Rails.logger.info("Processing #{messages.count} messages from previous conversation")

    attachments = fetch_attachments_for_messages(messages)

    build_message_data_with_attachments(messages, attachments)
  end

  def find_previous_conversation
    Conversation.where(
      account_id: Current.account.id,
      inbox_id: params[:inbox_id],
      contact_id: params[:contact_id]
    ).order(created_at: :desc).first
  end

  def fetch_messages(conversation)
    conversation.messages
                .order(created_at: :asc)
                .reject { |msg| msg.private && msg.content.include?('Conversation with') }
  end

  def fetch_attachments_for_messages(messages)
    message_ids = messages.map(&:id)
    Attachment.where(message_id: message_ids).group_by(&:message_id)
  end

  def build_message_data_with_attachments(messages, attachments)
    messages.map do |message|
      message_data = build_message_data(message)
      message_attachments = attachments[message.id] || []
      add_attachments_to_message_data(message_data, message_attachments)
      message_data
    end
  end

  def build_message_data(message)
    Rails.logger.info("Building message data for message: #{message.id}")
    {
      message_attributes: message.attributes.except('id', 'conversation_id').merge(
        additional_attributes: (message.additional_attributes || {}).merge(
          ignore_automation_rules: true,
          disable_notifications: true
        )
      ),
      attachments: []
    }
  end

  def add_attachments_to_message_data(message_data, attachments)
    attachments.each do |attachment|
      attachment_data = build_attachment_data(attachment)
      message_data[:attachments] << attachment_data
      Rails.logger.info("Processed attachment: #{attachment.id}")
    end
  end

  def build_attachment_data(attachment)
    attachment_data = { attributes: attachment.attributes.except('id', 'message_id') }
    add_active_storage_data(attachment, attachment_data)
    attachment_data
  end

  def add_active_storage_data(attachment, attachment_data)
    Rails.logger.info("Adding ActiveStorage data for attachment: #{attachment.id}")
    return unless attachment.file.attached?

    attachment_data[:active_storage_data] = {
      name: attachment.file.filename,
      record_type: 'Attachment',
      blob_id: attachment.file.blob.id,
      created_at: Time.zone.now
    }
    Rails.logger.info("Added ActiveStorage data for attachment: #{attachment.id}")
  end

  def permitted_update_params
    # TODO: Move the other conversation attributes to this method and remove specific endpoints for each attribute
    params.permit(:priority)
  end

  def update_last_seen_on_conversation(last_seen_at, update_assignee)
    # rubocop:disable Rails/SkipsModelValidations
    @conversation.update_column(:agent_last_seen_at, last_seen_at)
    @conversation.update_column(:assignee_last_seen_at, last_seen_at) if update_assignee.present?
    # rubocop:enable Rails/SkipsModelValidations
  end

  def set_conversation_status
    @conversation.status = params[:status]
    @conversation.snoozed_until = parse_date_time(params[:snoozed_until].to_s) if params[:snoozed_until]
  end

  def assign_conversation
    @conversation.assignee = current_user
    @conversation.save!
  end

  def conversation
    @conversation ||= Current.account.conversations.find_by!(display_id: params[:id])
    authorize @conversation.inbox, :show?
  end

  def inbox
    return if params[:inbox_id].blank?

    @inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize @inbox, :show?
  end

  def contact
    return if params[:contact_id].blank?

    @contact = Current.account.contacts.find(params[:contact_id])
  end

  def contact_inbox
    @contact_inbox = build_contact_inbox

    # fallback for the old case where we do look up only using source id
    # In future we need to change this and make sure we do look up on combination of inbox_id and source_id
    # and deprecate the support of passing only source_id as the param
    @contact_inbox ||= ::ContactInbox.find_by!(source_id: params[:source_id])
    authorize @contact_inbox.inbox, :show?
  rescue ActiveRecord::RecordNotUnique
    render json: { error: 'source_id should be unique' }, status: :unprocessable_entity
  end

  def build_contact_inbox
    return if @inbox.blank? || @contact.blank?

    ContactInboxBuilder.new(
      contact: @contact,
      inbox: @inbox,
      source_id: params[:source_id],
      hmac_verified: hmac_verified?
    ).perform
  end

  def conversation_finder
    @conversation_finder ||= ConversationFinder.new(Current.user, params)
  end

  def assignee?
    @conversation.assignee_id? && Current.user == @conversation.assignee
  end
end

Api::V1::Accounts::ConversationsController.prepend_mod_with('Api::V1::Accounts::ConversationsController')
# rubocop:enable Metrics/ClassLength
