class AiBrain::ResponseJob < ApplicationJob
  queue_as :medium

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message&.incoming? && message.notifiable? && message.text?

    conversation = message.conversation
    # Jobs run in the default locale; the notes left for reception are written in the account's language.
    I18n.with_locale(conversation.account.locale) { conversation.with_lock { process_message(message, conversation) } }
  rescue AiBrain::Client::UnavailableError => e
    Rails.logger.warn("AI Brain unavailable for message #{message_id}: #{e.message}")
    I18n.with_locale(conversation.account.locale) { unavailable_handoff(conversation) } if conversation
  ensure
    Current.executed_by = nil
  end

  private

  def process_message(message, conversation)
    link = conversation.inbox.ai_brain_inbox
    return unless eligible?(message, conversation, link)

    state = conversation.ai_brain_conversation || conversation.build_ai_brain_conversation(account: conversation.account)
    client = AiBrain::Client.new
    status, result = client.send_session_message(
      session_id: state.session_id,
      client_id: state.client_id,
      phone_number: phone_number_for(conversation),
      conversation_id: conversation.id,
      message_id: message.id,
      contact_id: conversation.contact_id
    )
    if status != 200
      error_handoff(conversation, "AI Brain: #{result&.dig('error') || "HTTP #{status}"}")
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
      error_handoff(conversation, I18n.t('ai_brain.errors.unavailable')) if conversation.pending?
    end
  end

  def process_outcome(conversation, message, state, result, client)
    case result.fetch('outcome').to_s
    when '0', 'Reply'
      deliver_and_confirm(conversation, message, result, client)
      note_staff_question(conversation, result, client)
    when '1', 'AwaitingReview'
      request_review(conversation, message, state, result, client)
    when '2', 'Handoff'
      human_handoff(conversation, message, state, result, client)
    when '4', 'SessionClosed'
      close_session(conversation, message, state, result, client)
    else
      error_handoff(conversation, I18n.t('ai_brain.errors.unknown_outcome'))
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

  def close_session(conversation, message, state, result, client)
    # Reset first so the next message starts a new session even if delivery fails.
    state.reset_to_bot!
    deliver_and_confirm(conversation, message, result, client, content_type: AiBrain::ClosingMessage.content_type(conversation))
    # Attributes the resolve activity to the bot; it is read when the surrounding lock transaction commits.
    Current.executed_by = AiBrain::BotSender.for(conversation.account)
    # Clear waiting_since in the same save: otherwise the farewell's commit callback saves the conversation
    # first and its status change (which sends the CSAT survey) never reaches the commit callbacks.
    conversation.update!(status: :resolved, waiting_since: nil)
  end

  def deliver_and_confirm(conversation, message, result, client, content_type: :text)
    # A receptionist can take over while the agent is running; the backend then discards the reply.
    return if result['textToSend'].blank?

    session_id = result['sessionId']
    delivery = AiBrain::Delivery.new(conversation: conversation, client: client, source_message_id: message.id, session_id: session_id)
    delivery.deliver!(result.fetch('textToSend'), result['outgoingMessageId'], content_type: content_type)
    follow_ups = result['followUpMessages']
    AiBrain::FollowUpJob.schedule(conversation.id, message.id, session_id, follow_ups) if follow_ups.present?
  end

  # The bot asked the clinic instead of handing off: the conversation stays with it, and a note tells whoever reads
  # the conversation what to answer.
  def note_staff_question(conversation, result, client)
    question_id = result['staffQuestionId']
    return if question_id.blank?

    status, questions = client.get("conversations/#{conversation.id}/staff-questions")
    question = questions.find { |candidate| candidate['id'] == question_id } if status == 200
    return unless question

    conversation.messages.create!(account: conversation.account, inbox: conversation.inbox, message_type: :outgoing, private: true,
                                  content: I18n.t('ai_brain.staff_question_note', question: question['question']))
  rescue AiBrain::Client::UnavailableError => e
    # The reply already went out; only the note is missing, and the header still lists the question.
    Rails.logger.warn("AI Brain staff question note skipped for conversation #{conversation.id}: #{e.message}")
  end

  def handoff(conversation, text)
    state = conversation.ai_brain_conversation || conversation.build_ai_brain_conversation(account: conversation.account)
    state.update!(state: 'human') if state.new_record? || state.bot?
    conversation.messages.create!(account: conversation.account, inbox: conversation.inbox, message_type: :outgoing,
                                  private: true, content: text)
    conversation.bot_handoff!
  end

  # Unlike the backend's own handoff outcomes, a failed turn leaves the backend session with the bot.
  def error_handoff(conversation, text)
    handoff(conversation, text)
    AiBrain::SessionHandoffJob.perform_later(conversation.id, text)
  end
end
