class AiBrainListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return unless eligible?(message)

    AiBrain::ResponseJob.perform_later(message.id)
  end

  private

  def eligible?(message)
    message.incoming? && message.notifiable? && message.text? && message.inbox.ai_brain_active? && message.conversation.pending? &&
      message.conversation.ai_brain_conversation&.state.in?([nil, 'bot'])
  end
end
