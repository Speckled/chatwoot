class AiBrainConversation < ApplicationRecord
  # The inactivity prompts of a person's chat (LRB-85): the question whether the patient's issue is solved ('notice'), the
  # person's answer to it ('solved', 'unsolved'), and the mandatory close ('close_required').
  INACTIVITY_PROMPTS = %w[notice solved unsolved close_required].freeze

  belongs_to :account
  belongs_to :conversation

  validates :conversation_id, uniqueness: true
  validates :state, inclusion: { in: %w[bot human review] }
  validates :inactivity_prompt, inclusion: { in: INACTIVITY_PROMPTS }, allow_nil: true
  validate :conversation_belongs_to_account

  def bot?
    state == 'bot'
  end

  def reset_to_bot!
    update!(state: 'bot', review_id: nil, source_message_id: nil, session_id: nil, active_workflow: nil)
    show_inactivity_prompt!(nil)
  end

  # Shows the prompt, or clears it with nil, and tells the dashboards that show the conversation to load it again.
  def show_inactivity_prompt!(prompt)
    return if inactivity_prompt == prompt

    update!(inactivity_prompt: prompt, inactivity_prompted_at: prompt && Time.current)
    # The dashboard reloads the prompt when the conversation's updated_at moves; nothing on the conversation itself changed.
    conversation.touch # rubocop:disable Rails/SkipsModelValidations
    conversation.dispatch_conversation_updated_event
  end

  private

  def conversation_belongs_to_account
    errors.add(:conversation_id, :invalid) if conversation && conversation.account_id != account_id
  end
end
