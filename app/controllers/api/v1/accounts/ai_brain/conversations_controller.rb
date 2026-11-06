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
      staffQuestions: open_staff_questions(conversation),
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

  # Answers a question the bot asked the clinic: the backend records it and words the message, which goes to the patient
  # as the bot's.
  def answer_question
    conversation = find_conversation
    text = params.require(:text).to_s.strip
    return render json: { error: I18n.t('ai_brain.errors.empty_reply') }, status: :unprocessable_entity if text.blank?

    status, delivery = client.post("staff-questions/#{uuid_param!(:question_id)}/answer", operatorId: Current.user.id, text: text)
    return render_upstream([status, delivery]) unless status == 200

    conversation.with_lock { post_staff_answer(conversation, delivery) }
    head :no_content
  end

  private

  def open_staff_questions(conversation)
    status, questions = client.get("conversations/#{conversation.id}/staff-questions")
    status == 200 ? questions.select { |question| question['status'] == 'open' } : []
  rescue AiBrain::Client::UnavailableError
    []
  end

  def post_staff_answer(conversation, delivery)
    question_id = delivery.fetch('questionId')
    message = conversation.messages.find_by(["additional_attributes ->> 'ai_brain_staff_question_id' = ?", question_id]) ||
              conversation.messages.create!(account: Current.account, inbox: conversation.inbox, message_type: :outgoing,
                                            content: delivery.fetch('textToSend'), sender: AiBrain::BotSender.for(Current.account),
                                            additional_attributes: { ai_brain_staff_question_id: question_id,
                                                                     ai_brain_session_id: delivery['sessionId'],
                                                                     ai_brain_outgoing_id: delivery['outgoingMessageId'] }.compact)
    return if delivery['outgoingMessageId'].blank?

    client.confirm_delivery(session_id: delivery['sessionId'], outgoing_message_id: delivery['outgoingMessageId'], chatwoot_message_id: message.id)
  end

  def find_conversation
    Current.account.conversations.find_by!(display_id: params[:conversation_id])
  end

  def validate_reply(conversation, text)
    state = conversation.ai_brain_conversation
    return render json: { error: I18n.t('ai_brain.errors.not_review') }, status: :conflict unless state&.state == 'review'

    result = client.post("reviews/#{state.review_id}/resolve", operatorId: Current.user.id, approved: true, editedReplyText: text)
    return render_upstream(result) unless result.first == 200

    reply = result.last
    sent_message = send_validated_reply(conversation, state.review_id, reply)
    confirmation = client.confirm_delivery(session_id: reply.fetch('sessionId'),
                                           outgoing_message_id: reply.fetch('outgoingMessageId'),
                                           chatwoot_message_id: sent_message.id)
    return render_upstream(confirmation) unless confirmation.first == 200

    state.update!(state: 'bot', review_id: nil, source_message_id: nil)
    conversation.pending! if conversation.open? && conversation.inbox.ai_brain_active?
    render json: { state: 'bot' }
  end

  def send_validated_reply(conversation, review_id, reply)
    existing = conversation.messages.find_by(["additional_attributes ->> 'ai_brain_review_id' = ?", review_id])
    return existing if existing

    conversation.messages.create!(account: Current.account, inbox: conversation.inbox, message_type: :outgoing,
                                  content: reply.fetch('textToSend'), sender: Current.user,
                                  additional_attributes: { ai_brain_review_id: review_id,
                                                           ai_brain_session_id: reply.fetch('sessionId'),
                                                           ai_brain_outgoing_id: reply.fetch('outgoingMessageId') })
  end
end
