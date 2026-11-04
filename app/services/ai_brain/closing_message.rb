# When the AI Brain closes a session, its closing message doubles as the CSAT survey on inboxes that send a survey
# message as its text with the survey button (WhatsApp Cloud, and the test provider that stands in for it in the test
# lab). The patient gets one message, the farewell with the button, and CsatSurveyService then finds the survey sent.
class AiBrain::ClosingMessage
  SURVEY_BUTTON_PROVIDERS = %w[whatsapp_cloud test].freeze

  def self.content_type(conversation)
    channel = conversation.inbox.channel
    survey = channel.is_a?(Channel::Whatsapp) && SURVEY_BUTTON_PROVIDERS.include?(channel.provider) &&
             CsatSurveyService.new(conversation: conversation).due?
    survey ? :input_csat : :text
  end
end
