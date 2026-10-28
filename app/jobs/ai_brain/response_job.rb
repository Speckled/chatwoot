class AiBrain::ResponseJob < ApplicationJob
  queue_as :medium

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message&.incoming? && message.notifiable? && message.text?

    conversation = message.conversation
    conversation.with_lock { process_message(message, conversation) }
  rescue AiBrain::Client::UnavailableError => e
    Rails.logger.warn("AI Brain unavailable for message #{message_id}: #{e.message}")
    unavailable_handoff(conversation) if conversation
  end

  private

  def process_message(message, conversation)
    link = conversation.inbox.ai_brain_inbox
    return unless eligible?(message, conversation, link)

    state = conversation.ai_brain_conversation || conversation.build_ai_brain_conversation(account: conversation.account)
    client = AiBrain::Client.new
    status, result = client.send_session_message(
      session_id: state.session_id,
      phone_number: phone_number_for(conversation),
      conversation_id: conversation.id,
      message_id: message.id,
      contact_id: conversation.contact_id
    )
    if status != 200
      handoff(conversation, "AI Brain: #{result&.dig('error') || "HTTP #{status}"}")
      return
    end

    sync_session_metadata!(state, result)
    process_outcome(conversation, message, state, result, client)
  end

  def eligible?(message, conversation, link)
    link&.active? && conversation.pending? && conversation.ai_brain_conversation&.state.in?([nil, 'bot']) &&
      !conversation.messages.incoming.where(private: false).exists?(['id > ?', message.id]) &&
      !conversation.messages.exists?(["additional_attributes ->> 'ai_brain_message_id' = ?", message.id.to_s])
  end

  def phone_number_for(conversation)
    contact = conversation.contact
    contact&.phone_number.presence ||
      contact&.identifier.presence ||
      conversation.contact_inbox&.source_id.presence ||
      "contact-#{conversation.contact_id}"
  end

  def sync_session_metadata!(state, result)
    state.assign_attributes(
      session_id: result['sessionId'] || state.session_id,
      active_workflow: result['activeWorkflow']&.to_s,
      client_id: result['clientId']
    )
    state.save! if state.changed? || state.new_record?
  end

  def unavailable_handoff(conversation)
    conversation.with_lock do
      handoff(conversation, I18n.t('ai_brain.errors.unavailable')) if conversation.pending?
    end
  end

  def process_outcome(conversation, message, state, result, client)
    case result.fetch('outcome').to_s
    when '0', 'Reply'
      deliver_and_confirm(conversation, message, result, client)
    when '1', 'AwaitingReview'
      request_review(conversation, message, state, result, client)
    when '2', 'Handoff'
      human_handoff(conversation, message, state, result, client)
    else
      handoff(conversation, I18n.t('ai_brain.errors.unknown_outcome'))
    end
  end

  def request_review(conversation, message, state, result, client)
    review_id = result.fetch('reviewId')
    review_status, reviews = client.get('reviews/pending')
    review = reviews.find { |candidate| candidate['id'] == review_id } if review_status == 200
    raise AiBrain::Client::UnavailableError, 'Review draft unavailable' unless review

    state.update!(state: 'review', review_id: review_id, source_message_id: message.id)
    deliver_and_confirm(conversation, message, result, client)
    handoff(conversation, I18n.t('ai_brain.review_note', reply: review['proposedReplyText'], reason: review['reason']))
  end

  def human_handoff(conversation, message, state, result, client)
    state.update!(state: 'human', review_id: nil, source_message_id: nil)
    deliver_and_confirm(conversation, message, result, client)
    handoff(conversation, I18n.t('ai_brain.handoff_note', reason: result['reason']))
  end

  def deliver_and_confirm(conversation, message, result, client)
    session_id = result['sessionId']
    outgoing_id = result['outgoingMessageId']
    sent_message = send_message(conversation, result.fetch('textToSend'), message.id, outgoing_id)
    return unless session_id.present? && outgoing_id.present?

    client.confirm_delivery(
      session_id: session_id,
      outgoing_message_id: outgoing_id,
      chatwoot_message_id: sent_message.id,
      status: 1
    )
  rescue StandardError => e
    if session_id.present? && outgoing_id.present?
      begin
        client.confirm_delivery(
          session_id: session_id,
          outgoing_message_id: outgoing_id,
          status: 2,
          error_reason: e.message
        )
      rescue StandardError
        nil
      end
    end
    raise
  end

  def send_message(conversation, text, source_id, outgoing_id = nil)
    conversation.messages.create!(
      account: conversation.account,
      inbox: conversation.inbox,
      message_type: :outgoing,
      content: text,
      sender: AiBrain::BotSender.for(conversation.account),
      additional_attributes: {
        ai_brain_message_id: source_id.to_s,
        ai_brain_outgoing_id: outgoing_id.to_s.presence
      }.compact
    )
  end

  def handoff(conversation, text)
    state = conversation.ai_brain_conversation || conversation.build_ai_brain_conversation(account: conversation.account)
    state.update!(state: 'human') if state.new_record? || state.bot?
    conversation.messages.create!(account: conversation.account, inbox: conversation.inbox, message_type: :outgoing,
                                  private: true, content: text)
    conversation.bot_handoff!
  end
end
