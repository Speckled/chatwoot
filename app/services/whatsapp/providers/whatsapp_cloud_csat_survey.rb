# How the WhatsApp Cloud provider sends the CSAT survey message inside the customer service window: as the inbox's
# WhatsApp Flow when one is attached (see docs/whatsapp_csat_flow.md), otherwise as the survey link behind a button
# instead of a raw URL in the text. Both buttons are labelled with the inbox's CSAT button text.
module Whatsapp::Providers::WhatsappCloudCsatSurvey
  private

  def send_csat_survey_message(phone_number, message)
    response = HTTParty.post(
      "#{phone_id_path('v24.0')}/messages",
      headers: api_headers,
      body: {
        messaging_product: 'whatsapp', **recipient_params(phone_number), type: 'interactive', interactive: csat_survey_payload(message)
      }.to_json
    )

    process_response(response, message)
  end

  def csat_survey_payload(message)
    csat_config = whatsapp_channel.inbox.csat_config
    return csat_flow_payload(message, csat_config) if csat_config['whatsapp_flow'].present?

    {
      type: 'cta_url',
      body: { text: message.content },
      # Meta allows up to 20 characters for display_text.
      action: { name: 'cta_url', parameters: { display_text: csat_config['button_text'], url: message.conversation.csat_survey_link } }
    }
  end

  # The patient's answers come back as an nfm_reply, recorded by Whatsapp::CsatFlowService.
  def csat_flow_payload(message, csat_config)
    {
      type: 'flow',
      body: { text: message.content },
      action: {
        name: 'flow',
        parameters: {
          flow_message_version: '3',
          flow_token: Whatsapp::CsatFlowService.flow_token(message.conversation),
          flow_id: csat_config['whatsapp_flow']['flow_id'],
          flow_cta: csat_config['button_text'],
          flow_action: 'navigate'
        }
      }
    }
  end
end
