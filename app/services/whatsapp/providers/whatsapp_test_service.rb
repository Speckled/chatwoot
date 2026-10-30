# Local-only WhatsApp provider used by the AI Brain test lab.
# Test inboxes behave like regular WhatsApp inboxes inside Chatwoot, but never
# talk to Meta / 360Dialog: outgoing messages are marked as sent with a fake id.
class Whatsapp::Providers::WhatsappTestService < Whatsapp::Providers::BaseService
  def send_message(_phone_number, _message)
    fake_message_id
  end

  def send_template(_phone_number, _template_info, _message)
    fake_message_id
  end

  def sync_templates
    whatsapp_channel.mark_message_templates_updated
  end

  def validate_provider_config?
    true
  end

  def api_headers
    {}
  end

  def media_url(_media_id)
    nil
  end

  def error_message(_response)
    nil
  end

  private

  def fake_message_id
    "wamid.test.#{SecureRandom.hex(8)}"
  end
end
