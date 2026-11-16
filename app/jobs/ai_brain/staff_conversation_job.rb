# Runs one turn of the staff agent for a message a staff member wrote in their staff conversation, with or without a
# Chatwoot login, and posts the reply in the same conversation as the AI Brain bot. The conversation keeps its staff
# audience, so only administrators see it. The backend finds the person by the number WhatsApp delivered the message
# from: the conversation's contact_inbox source_id, which only WhatsApp sets. The contact's phone_number and staff flag
# are editable by any agent and may decide only whether the staff agent answers, never as whom. Only the message ID is
# queued, and the message text never reaches the logs.
class AiBrain::StaffConversationJob < ApplicationJob
  # The backend is still running an earlier turn of this person (409) or failed.
  class RetryableError < StandardError; end

  queue_as :medium

  retry_on RetryableError, AiBrain::Client::UnavailableError, wait: 5.seconds, attempts: 6 do |job, error|
    Rails.logger.warn("AI Brain staff conversation turn failed: #{error.message}")
    job.apologize
  end

  # A text or voice message the contact wrote, as staff, in a staff conversation of an inbox the AI Brain serves. A contact
  # who stopped being staff has lost the flag, and patients' conversations never have the staff audience.
  def self.handles?(message)
    conversation = message.conversation
    message.incoming? && !message.private? && conversation.ai_brain_staff? && message.inbox.ai_brain_active? &&
      staff_sender?(conversation) && (message.content.present? || audio_of(message).present?)
  end

  # The contact is flagged as staff in the inbox, and WhatsApp names the number they write from.
  def self.staff_sender?(conversation)
    Conversation.ai_brain_staff_contact?(conversation.contact, conversation.inbox_id) && sender_number(conversation).present?
  end

  # The sender's WhatsApp number in its canonical form; nil when the thread is keyed by WhatsApp's business scoped user id
  # rather than a number, as the backend could not tell who wrote.
  def self.sender_number(conversation)
    source_id = conversation.contact_inbox&.source_id.to_s
    AiBrainOwner.canonical_phone_number(source_id) if source_id.match?(/\A\d{1,15}\z/)
  end

  def self.audio_of(message)
    message.attachments.find(&:audio?)
  end

  def perform(message_id)
    @message = Message.find(message_id)
    status, result = AiBrain::Client.new.post('owner/messages', body)
    raise RetryableError, "AI Brain HTTP #{status}" unless status == 200

    # An empty reply means the backend does not know the number as one staff member: nothing is posted.
    return if result['textToSend'].blank?

    post(result['textToSend'])
    # Texts the model never writes, such as a one-time connect link, each its own message after the reply.
    Array(result['followUps']).each { |text| post(text) }
  end

  def apologize
    post(I18n.with_locale(@message.account.locale) { I18n.t('ai_brain.owner.unavailable') })
  end

  private

  def body
    audio = self.class.audio_of(@message)
    {
      phoneNumber: self.class.sender_number(@message.conversation),
      whatsAppMessageId: "chatwoot-#{@message.id}",
      inboxId: @message.inbox_id,
      messageType: audio ? 'audio' : 'text',
      text: audio ? nil : @message.content,
      audio: audio ? { data: audio.file.blob.open { |file| Base64.strict_encode64(file.read) }, contentType: audio.file.content_type } : nil,
      channel: 'staff_conversation'
    }
  end

  def post(text)
    conversation = @message.conversation
    conversation.messages.create!(account: conversation.account, inbox: conversation.inbox, message_type: :outgoing, content: text,
                                  sender: AiBrain::BotSender.for(conversation.account))
  end
end
