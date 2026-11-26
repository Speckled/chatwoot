class Api::V1::Apps::SessionsController < Api::V1::Apps::BaseController
  def outbound
    conversation = find_conversation
    return render json: { error: 'Conversation not found' }, status: :not_found unless conversation

    sent_message = nil
    conversation.with_lock do
      text = params[:textToSend].to_s.strip
      outcome = params[:outcome].to_s
      outgoing_id = params[:outgoingMessageId]
      closing = outcome.in?(['4', 'SessionClosed'])

      if text.present?
        sent_message = conversation.messages.create!(
          account: conversation.account,
          inbox: conversation.inbox,
          message_type: :outgoing,
          content: text,
          content_type: closing ? AiBrain::ClosingMessage.content_type(conversation) : :text,
          sender: AiBrain::BotSender.for(conversation.account),
          # Outside WhatsApp's 24-hour window the AI Brain gives the approved template to send in place of the text.
          additional_attributes: {
            ai_brain_session_id: params[:session_id].to_s,
            ai_brain_outgoing_id: outgoing_id.to_s.presence,
            ai_brain_outcome: outcome,
            template_params: AiBrain::TemplateParams.build(params[:template].presence)
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

      if closing
        conversation.ai_brain_conversation&.reset_to_bot!
        Current.executed_by = AiBrain::BotSender.for(conversation.account)
        resolve(conversation, silently: text.blank?)
      end
    end

    render json: { success: true, chatwootMessageId: sent_message&.id }, status: :ok
  ensure
    Current.executed_by = nil
  end

  private

  # A close with no text is a close for inactivity: the patient is told nothing, so no CSAT survey goes out either.
  # Otherwise the status changes in the same save as waiting_since, so it still dispatches and sends the survey.
  def resolve(conversation, silently:)
    return if conversation.resolved?

    silently ? conversation.ai_brain_resolve_silently! : conversation.update!(status: :resolved, waiting_since: nil)
  end

  def find_conversation
    by_session = AiBrainConversation.find_by(session_id: params[:session_id])&.conversation if params[:session_id].present?
    by_session || (Conversation.find_by(id: params[:chatwootConversationId]) if params[:chatwootConversationId].present?)
  end
end
