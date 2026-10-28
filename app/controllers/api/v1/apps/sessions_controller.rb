class Api::V1::Apps::SessionsController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :set_current_user
  before_action :verify_api_key!

  def outbound
    conversation = find_conversation
    return render json: { error: 'Conversation not found' }, status: :not_found unless conversation

    sent_message = nil
    conversation.with_lock do
      text = params[:textToSend].to_s.strip
      outcome = params[:outcome].to_s
      outgoing_id = params[:outgoingMessageId]

      if text.present?
        sent_message = conversation.messages.create!(
          account: conversation.account,
          inbox: conversation.inbox,
          message_type: :outgoing,
          content: text,
          sender: AiBrain::BotSender.for(conversation.account),
          additional_attributes: {
            ai_brain_session_id: params[:session_id].to_s,
            ai_brain_outgoing_id: outgoing_id.to_s.presence,
            ai_brain_outcome: outcome
          }.compact
        )
      end

      if outgoing_id.present? && sent_message
        begin
          AiBrain::Client.new(params[:app_id]).confirm_delivery(
            session_id: params[:session_id],
            outgoing_message_id: outgoing_id,
            chatwoot_message_id: sent_message.id,
            status: 1
          )
        rescue StandardError => e
          Rails.logger.warn("Failed to confirm outbound message delivery #{outgoing_id}: #{e.message}")
        end
      end

      if outcome.in?(['4', 'SessionClosed'])
        conversation.ai_brain_conversation&.reset_to_bot!
        conversation.resolved! unless conversation.resolved?
      end
    end

    render json: { success: true, chatwootMessageId: sent_message&.id }, status: :ok
  end

  private

  def verify_api_key!
    expected = ENV.fetch('AI_BRAIN_API_KEY', '').to_s
    supplied = request.headers['X-Api-Key'].to_s
    return if expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, supplied)

    render json: { error: 'Unauthorized' }, status: :unauthorized
  end

  def find_conversation
    by_session = AiBrainConversation.find_by(session_id: params[:session_id])&.conversation if params[:session_id].present?
    by_session || (Conversation.find_by(id: params[:chatwootConversationId]) if params[:chatwootConversationId].present?)
  end
end
