# Conversations the AI Brain starts to message staff, such as a reminder to a professional, through the clinic's own
# inboxes. Only account administrators see them, and the AI never answers them. The contact is flagged too, so a new
# conversation the staff member starts later, by writing back, is staff-only as well.
module AiBrainStaffConversation
  extend ActiveSupport::Concern

  AUDIENCE_KEY = 'ai_brain_audience'.freeze
  STAFF_AUDIENCE = 'staff'.freeze
  STAFF_CONTACT_KEY = 'ai_brain_staff'.freeze

  included do
    scope :ai_brain_staff, -> { where("conversations.additional_attributes->>'ai_brain_audience' = 'staff'") }
    scope :without_ai_brain_staff, -> { where("conversations.additional_attributes->>'ai_brain_audience' IS DISTINCT FROM 'staff'") }

    before_create :inherit_ai_brain_staff_audience
  end

  class_methods do
    def ai_brain_staff_contact?(contact)
      contact&.additional_attributes&.dig(STAFF_CONTACT_KEY) == true
    end
  end

  def ai_brain_staff?
    additional_attributes&.dig(AUDIENCE_KEY) == STAFF_AUDIENCE
  end

  # The inbox's agents who may see the conversation; administrators always may.
  def ai_brain_visible_members
    ai_brain_staff? ? User.none : inbox.members
  end

  def ai_brain_hidden_from?(user)
    ai_brain_staff? && !account.administrators.exists?(user.id)
  end

  # Whether the AI may answer: never in a staff conversation, and otherwise while no person has taken it over.
  def ai_brain_bot_owned?
    !ai_brain_staff? && ai_brain_conversation&.state.in?([nil, 'bot'])
  end

  private

  def inherit_ai_brain_staff_audience
    return unless self.class.ai_brain_staff_contact?(contact)

    self.additional_attributes = (additional_attributes || {}).merge(AUDIENCE_KEY => STAFF_AUDIENCE)
  end
end
