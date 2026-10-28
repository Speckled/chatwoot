class Api::V1::Accounts::AiBrain::ConversationsController < Api::V1::Accounts::AiBrain::BaseController
  def show
    conversation = find_conversation
    state = conversation.ai_brain_conversation
    review = nil
    if state&.state == 'review'
      status, reviews = client.get('reviews/pending')
      return render_upstream([status, reviews]) unless status == 200

      review = reviews.find { |item| item['id'] == state.review_id }
    end
    render json: {
      state: state&.state || 'bot',
      sessionId: state&.session_id,
      activeWorkflow: state&.active_workflow,
      clientId: state&.client_id,
      review: review,
      aiEnabled: conversation.inbox.ai_brain_active?
    }
  end

  def end_session
    conversation = find_conversation
    conversation.with_lock do
      state = conversation.ai_brain_conversation
      return render json: { error: I18n.t('ai_brain.errors.not_human') }, status: :conflict unless state&.state == 'human'

      result = if state.session_id.present?
                 client.post("sessions/#{state.session_id}/resume")
               else
                 client.post("conversations/#{conversation.id}/session/end")
               end
      return render_upstream(result) unless result.first.in?([200, 204])

      state.update!(state: 'bot', review_id: nil, source_message_id: nil)
      conversation.pending! if conversation.open? && conversation.inbox.ai_brain_active?
      head :no_content
    end
  end

  def validate_review
    conversation = find_conversation
    text = params.require(:text).to_s.strip
    return render json: { error: I18n.t('ai_brain.errors.empty_reply') }, status: :unprocessable_entity if text.blank?

    conversation.with_lock { validate_reply(conversation, text) }
  end

  private

  def find_conversation
    Current.account.conversations.find_by!(display_id: params[:conversation_id])
  end

  def validate_reply(conversation, text)
    state = conversation.ai_brain_conversation
    return render json: { error: I18n.t('ai_brain.errors.not_review') }, status: :conflict unless state&.state == 'review'

    result = client.post("reviews/#{state.review_id}/resolve", operatorId: Current.user.id, approved: true, editedReplyText: text)
    return render_upstream(result) unless result.first == 200

    send_validated_reply(conversation, state.review_id, result.last.fetch('textToSend'))
    state.update!(state: 'bot', review_id: nil, source_message_id: nil)
    conversation.pending! if conversation.open? && conversation.inbox.ai_brain_active?
    render json: { state: 'bot' }
  end

  def send_validated_reply(conversation, review_id, text)
    return if conversation.messages.exists?(["additional_attributes ->> 'ai_brain_review_id' = ?", review_id])

    conversation.messages.create!(account: Current.account, inbox: conversation.inbox, message_type: :outgoing,
                                  content: text, sender: Current.user, additional_attributes: { ai_brain_review_id: review_id })
  end
end
