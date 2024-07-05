class Api::V1::Accounts::Conversations::DirectUploadsController < ActiveStorage::DirectUploadsController
  include EnsureCurrentAccountHelper
  before_action :current_account
  before_action :conversation

  def create
    if params[:blob].present? && params[:blob][:byte_size].to_i > 5.megabytes
      render json: { message: 'File size exceeds the maximum allowed (5 MB)' }, status: :unprocessable_entity
      return
    end

    return if @conversation.nil? || @current_account.nil?

    super
  end

  private

  def conversation
    @conversation ||= Current.account.conversations.find_by(display_id: params[:conversation_id])
  end
end
