# Posts a message the AI Brain wrote, as its bot, and confirms the delivery to the AI Brain. A failure is reported to the
# AI Brain and raised again; callers run it in a transaction, so the message is taken back with it.
class AiBrain::Delivery
  pattr_initialize [:conversation!, :client!, :source_message_id!, :session_id]

  def deliver!(text, outgoing_id, content_type: :text)
    sent_message = create_message(text, outgoing_id, content_type)
    return unless session_id.present? && outgoing_id.present?

    client.confirm_delivery(session_id: session_id, outgoing_message_id: outgoing_id, chatwoot_message_id: sent_message.id, status: 1)
  rescue StandardError => e
    report_failure(outgoing_id, e) if session_id.present? && outgoing_id.present?
    raise
  end

  private

  def create_message(text, outgoing_id, content_type)
    conversation.messages.create!(
      account: conversation.account,
      inbox: conversation.inbox,
      message_type: :outgoing,
      content: text,
      content_type: content_type,
      sender: AiBrain::BotSender.for(conversation.account),
      additional_attributes: {
        ai_brain_message_id: source_message_id.to_s,
        ai_brain_outgoing_id: outgoing_id.to_s.presence
      }.compact
    )
  end

  def report_failure(outgoing_id, error)
    client.confirm_delivery(session_id: session_id, outgoing_message_id: outgoing_id, status: 2, error_reason: error.message)
  rescue StandardError
    nil
  end
end
