# A conversation the AI Brain resolved for inactivity without a message. The patient is told nothing when a session closes
# that way, so the conversation gets no satisfaction survey either (CsatSurveyService#due?). The mark goes when the
# conversation leaves resolved, so a later resolve by a person or by Clara's farewell sends the survey as usual.
module AiBrainSilentClose
  extend ActiveSupport::Concern

  SILENT_CLOSE_KEY = 'ai_brain_silent_close'.freeze

  included do
    before_save :clear_ai_brain_silent_close, if: -> { status_changed? && !resolved? }
  end

  def ai_brain_silent_close?
    additional_attributes&.dig(SILENT_CLOSE_KEY) == true
  end

  # One save, so the status change that the survey listens to already carries the mark.
  def ai_brain_resolve_silently!
    update!(status: :resolved, waiting_since: nil, additional_attributes: (additional_attributes || {}).merge(SILENT_CLOSE_KEY => true))
  end

  private

  def clear_ai_brain_silent_close
    self.additional_attributes = additional_attributes.except(SILENT_CLOSE_KEY) if additional_attributes&.key?(SILENT_CLOSE_KEY)
  end
end
