class AiBrainConversation < ApplicationRecord
  belongs_to :account
  belongs_to :conversation

  validates :conversation_id, uniqueness: true
  validates :state, inclusion: { in: %w[bot human review] }
  validate :conversation_belongs_to_account

  def bot?
    state == 'bot'
  end

  def reset_to_bot!
    update!(state: 'bot', review_id: nil, source_message_id: nil, session_id: nil, active_workflow: nil)
  end

  private

  def conversation_belongs_to_account
    errors.add(:conversation_id, :invalid) if conversation && conversation.account_id != account_id
  end
end
