class AiBrainListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    # A staff member writing in their staff conversation talks to the staff agent; patients talk to the patient agent.
    if AiBrain::StaffConversationJob.handles?(message)
      AiBrain::StaffConversationJob.perform_later(message.id)
    elsif eligible?(message)
      AiBrain::ResponseJob.perform_later(message.id)
    end
  end

  # Opening a conversation the bot still owns means a receptionist took it over. The bot's own handoffs mark it human
  # before opening it.
  def conversation_opened(event)
    conversation = extract_conversation_and_account(event)[0]
    return unless ai_brain_session?(conversation)

    taken_over = conversation.with_lock do
      state = conversation.ai_brain_conversation || conversation.build_ai_brain_conversation(account: conversation.account)
      next false unless conversation.open? && (state.new_record? || state.bot?)

      state.update!(state: 'human')
    end
    AiBrain::SessionHandoffJob.perform_later(conversation.id, 'Taken over by a receptionist') if taken_over
  end

  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    return unless ai_brain_session?(conversation)

    AiBrain::SessionEndJob.perform_later(conversation.id)
  end

  private

  def eligible?(message)
    message.incoming? && message.notifiable? && message.text? && message.inbox.ai_brain_active? && message.conversation.pending? &&
      message.conversation.ai_brain_bot_owned?
  end

  # Staff conversations never have a patient's AI session; the staff agent keeps none in Chatwoot.
  def ai_brain_session?(conversation)
    conversation.inbox.ai_brain_inbox.present? && !conversation.ai_brain_staff?
  end
end
