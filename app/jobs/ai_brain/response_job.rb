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

    client = AiBrain::Client.new(conversation.account_id)
    status, result = client.execute(agent_id: link.agent_definition_id, conversation_display_id: conversation.display_id, message_id: message.id)
    if status != 200
      handoff(conversation, "AI Brain: #{result&.dig('error') || "HTTP #{status}"}")
      return
    end

    agent_status, agent = client.get("agents/#{link.agent_definition_id}")
    process_outcome(conversation, message, result, agent_status == 200 ? agent['name'] : nil, client)
  end

  def eligible?(message, conversation, link)
    link&.active? && conversation.pending? && conversation.ai_brain_conversation&.state.in?([nil, 'bot']) &&
      !conversation.messages.incoming.where(private: false).exists?(['id > ?', message.id]) &&
      !conversation.messages.exists?(["additional_attributes ->> 'ai_brain_message_id' = ?", message.id.to_s])
  end

  def unavailable_handoff(conversation)
    conversation.with_lock do
      handoff(conversation, I18n.t('ai_brain.errors.unavailable')) if conversation.pending?
    end
  end

  def process_outcome(conversation, message, result, agent_name, client)
    case result.fetch('outcome').to_s
    when '0', 'Reply'
      send_message(conversation, result.fetch('textToSend'), message.id, agent_name)
    when '1', 'AwaitingReview'
      request_review(conversation, message, result, agent_name, client)
    when '2', 'Handoff'
      human_handoff(conversation, message, result, agent_name)
    else
      handoff(conversation, I18n.t('ai_brain.errors.unknown_outcome'))
    end
  end

  def request_review(conversation, message, result, agent_name, client)
    review_id = result.fetch('reviewId')
    review_status, reviews = client.get('reviews/pending')
    review = reviews.find { |candidate| candidate['id'] == review_id } if review_status == 200
    raise AiBrain::Client::UnavailableError, 'Review draft unavailable' unless review

    state = conversation.ai_brain_conversation || conversation.build_ai_brain_conversation(account: conversation.account)
    state.update!(state: 'review', review_id: review_id, source_message_id: message.id)
    send_message(conversation, result.fetch('textToSend'), message.id, agent_name)
    handoff(conversation, I18n.t('ai_brain.review_note', reply: review['proposedReplyText'], reason: review['reason']))
  end

  def human_handoff(conversation, message, result, agent_name)
    state = conversation.ai_brain_conversation || conversation.build_ai_brain_conversation(account: conversation.account)
    state.update!(state: 'human', review_id: nil, source_message_id: nil)
    send_message(conversation, result.fetch('textToSend'), message.id, agent_name)
    handoff(conversation, I18n.t('ai_brain.handoff_note', reason: result['reason']))
  end

  def send_message(conversation, text, source_id, agent_name)
    conversation.messages.create!(account: conversation.account, inbox: conversation.inbox, message_type: :outgoing,
                                  content: text, sender: AiBrain::BotSender.for(conversation.account),
                                  additional_attributes: { agent_name: agent_name, ai_brain_message_id: source_id.to_s })
  end

  def handoff(conversation, text)
    state = conversation.ai_brain_conversation || conversation.build_ai_brain_conversation(account: conversation.account)
    state.update!(state: 'human') if state.new_record? || state.bot?
    conversation.messages.create!(account: conversation.account, inbox: conversation.inbox, message_type: :outgoing,
                                  private: true, content: text)
    conversation.bot_handoff!
  end
end
