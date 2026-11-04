# Records a CSAT survey submitted through the inbox's WhatsApp Flow (see docs/whatsapp_csat_flow.md).
# Like the web survey, it updates the conversation's survey message instead of creating a message: an incoming
# message would reopen the resolved conversation and hand it back to the bot.
class Whatsapp::CsatFlowResponseService
  TOKEN_PREFIX = 'csat:'.freeze
  # Same window as Public::Api::V1::CsatSurveyController.
  LOCK_AFTER_DAYS = 14

  pattr_initialize [:inbox!, :contact!, :flow_response!]

  def self.flow_token(conversation)
    "#{TOKEN_PREFIX}#{conversation.uuid}"
  end

  # True when the Flow response is a CSAT submission, recorded or not; other Flow responses are left to the caller.
  def perform
    return false unless flow_response.is_a?(Hash) && flow_token.start_with?(TOKEN_PREFIX)

    if survey_message.nil? || locked?
      Rails.logger.warn "[WHATSAPP_CSAT_FLOW] Dropped CSAT response #{flow_token} for inbox #{inbox.id}"
    else
      rating = Integer(flow_response['rating'])
      survey_message.update!(submitted_values: { csat_survey_response: { rating: rating, feedback_message: flow_response['comment'].presence } })
    end
    true
  end

  private

  def flow_token
    flow_response['flow_token'].to_s
  end

  def survey_message
    return @survey_message if defined?(@survey_message)

    conversation = inbox.conversations.find_by(uuid: flow_token.delete_prefix(TOKEN_PREFIX), contact: contact)
    @survey_message = conversation&.messages&.find_by(content_type: :input_csat)
  end

  def locked?
    (Time.zone.now.to_date - survey_message.created_at.to_date).to_i > LOCK_AFTER_DAYS
  end
end
