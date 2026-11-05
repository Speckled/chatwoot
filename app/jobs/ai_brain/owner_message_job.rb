# Runs one turn of the clinic owner's private assistant. Owner messages never reach Chatwoot, so the reply goes straight
# through the WhatsApp provider, and the arguments stay out of the logs because they carry the message text.
class AiBrain::OwnerMessageJob < ApplicationJob
  # The backend is still running an earlier owner turn (409) or failed, or WhatsApp did not serve the voice note.
  class RetryableError < StandardError; end

  FOLLOW_UP_DELAY_SECONDS = 1

  queue_as :medium
  self.log_arguments = false

  retry_on RetryableError, AiBrain::Client::UnavailableError, Down::Error, wait: 5.seconds, attempts: 6 do |job, error|
    Rails.logger.warn("AI Brain owner turn failed: #{error.message}")
    job.apologize
  end

  def perform(inbox_id, owner_id, from, message)
    @inbox = Inbox.find(inbox_id)
    @from = from
    owner = AiBrainOwner.find(owner_id)

    body = {
      ownerUserId: owner.user_id,
      phoneNumber: owner.phone_number,
      whatsAppMessageId: message['id'],
      inboxId: inbox_id,
      messageType: message['type'].in?(%w[text audio]) ? message['type'] : 'other',
      text: message['text'],
      audio: message['type'] == 'audio' ? download_audio(message) : nil
    }
    status, result = AiBrain::Client.new.post('owner/messages', body)
    raise RetryableError, "AI Brain HTTP #{status}" unless status == 200

    reply(result.fetch('textToSend'))
    send_follow_ups(Array(result['followUps']))
  end

  def apologize
    reply(I18n.with_locale(@inbox.account.locale) { I18n.t('ai_brain.owner.unavailable') })
  end

  private

  def reply(text)
    @inbox.channel.provider_service.send_text(@from, text)
  end

  # Texts the model never writes, such as a one-time connect link, each its own message after the reply. The pause keeps
  # them in order on the owner's phone.
  def send_follow_ups(texts)
    texts.each do |text|
      sleep(FOLLOW_UP_DELAY_SECONDS)
      reply(text)
    end
  end

  # Same lookup as Whatsapp::IncomingMessageWhatsappCloudService#download_attachment_file.
  def download_audio(message)
    channel = @inbox.channel
    url_response = HTTParty.get(channel.media_url(message['audio_id']), headers: channel.api_headers)
    channel.authorization_error! if url_response.unauthorized?
    raise RetryableError, "WhatsApp media HTTP #{url_response.code}" unless url_response.success?

    file = Down.download(url_response.parsed_response['url'], headers: channel.api_headers)
    { data: Base64.strict_encode64(file.read), contentType: message['mime_type'] }
  ensure
    file&.close!
  end
end
