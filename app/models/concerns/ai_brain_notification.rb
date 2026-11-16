# The AI Brain's notification (LRB-85): a person's chat went quiet. Its meta holds the stage ('notice' asks whether the
# patient's issue is solved, 'close_required' asks to close) and the minutes without a message. It reaches the mobile app
# whatever the person's notification settings, since the prompt waits for them.
module AiBrainNotification
  def push_message_title
    return super unless ai_brain_session_inactive?

    I18n.t("notifications.notification_title.ai_brain_session_inactive.#{meta&.dig('stage') || 'notice'}",
           display_id: conversation.display_id, minutes: meta&.dig('minutes'))
  end

  def push_message_body
    return super unless ai_brain_session_inactive?

    message_body(conversation.messages.incoming.last || conversation.messages.outgoing.last)
  end

  private

  def user_subscribed_to_notification?(delivery_type)
    (ai_brain_session_inactive? && delivery_type == 'push') || super
  end
end
