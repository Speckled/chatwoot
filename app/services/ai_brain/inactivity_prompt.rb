# Shows a quiet AI Brain conversation's inactivity prompt and notifies the person who has the conversation (LRB-85): its
# assignee, or the account's administrators when nobody is assigned, and only people who can see it. The backend decides
# when; asking again for the prompt already shown changes nothing, so its retries notify nobody twice.
class AiBrain::InactivityPrompt
  STAGES = %w[notice close_required].freeze

  pattr_initialize [:conversation!, :stage!, :minutes!]

  def perform
    conversation.with_lock do
      state = conversation.ai_brain_conversation || conversation.build_ai_brain_conversation(account: conversation.account)
      next if state.inactivity_prompt == stage

      state.save! if state.new_record?
      state.show_inactivity_prompt!(stage)
      recipients.each { |user| notify(user) }
    end
  end

  private

  def recipients
    candidates = conversation.assignee ? [conversation.assignee] : conversation.account.administrators.to_a
    candidates.select { |user| can_see?(user) }
  end

  def can_see?(user)
    account_user = AccountUser.find_by(account_id: conversation.account_id, user_id: user.id)
    account_user.present? &&
      ConversationPolicy.new({ user: user, account: conversation.account, account_user: account_user }, conversation).show?
  end

  def notify(user)
    user.notifications.create!(notification_type: :ai_brain_session_inactive, account: conversation.account, primary_actor: conversation,
                               meta: { stage: stage, minutes: minutes })
  end
end
