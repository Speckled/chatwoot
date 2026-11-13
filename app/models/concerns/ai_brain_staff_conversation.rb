# Conversations the AI Brain starts to message staff, such as a reminder to a professional, through the clinic's own
# inboxes. Only account administrators see them, and the AI never answers them. A contact flagged as staff for an inbox
# (STAFF_INBOXES_KEY) makes every conversation created there afterwards staff-only as well. The AI Brain flags a staff
# member's contact in every AI Brain WhatsApp inbox as soon as they have a WhatsApp number, and takes the flag off when
# they stop being staff (Apps::StaffController); a message the bot sends to staff flags its inbox too. An inbox the AI
# Brain starts serving later is added to every flagged contact (AiBrainInbox). Existing conversations never change.
module AiBrainStaffConversation
  extend ActiveSupport::Concern

  AUDIENCE_KEY = 'ai_brain_audience'.freeze
  STAFF_AUDIENCE = 'staff'.freeze
  STAFF_INBOXES_KEY = 'ai_brain_staff_inbox_ids'.freeze

  included do
    scope :ai_brain_staff, -> { where("conversations.additional_attributes->>'ai_brain_audience' = 'staff'") }
    scope :without_ai_brain_staff, -> { where("conversations.additional_attributes->>'ai_brain_audience' IS DISTINCT FROM 'staff'") }

    before_create :inherit_ai_brain_staff_audience
  end

  class_methods do
    def ai_brain_staff_contact?(contact, inbox_id)
      Array(contact&.additional_attributes&.dig(STAFF_INBOXES_KEY)).include?(inbox_id)
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
    return unless self.class.ai_brain_staff_contact?(contact, inbox_id)

    self.additional_attributes = (additional_attributes || {}).merge(AUDIENCE_KEY => STAFF_AUDIENCE)
  end
end
