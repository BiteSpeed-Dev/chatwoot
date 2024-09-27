# app/controllers/webhooks/call_controller.rb
class Webhooks::CallController < ActionController::API
  def handle_call_callback
    payload = request.body # Ensure you call .read to get the body content
    conversation = Conversation.where({
      account_id: params[:account_id],
      inbox_id: params[:inbox_id],
      display_id: params[:conversation_id]
    }).first

    
    conversation.messages.create!(private_message_params(payload.to_json, conversation))
    head :ok
  end

  def private_message_params(content, conversation)
    { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :outgoing, content: content, private: true }
  end
end
