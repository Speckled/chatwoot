module InboxBotStatus
  extend ActiveSupport::Concern

  def active_bot?
    external_bot_active? || ai_brain_active?
  end

  def ai_brain_active?
    ai_brain_inbox&.active? || false
  end

  def external_bot_active?
    agent_bot_inbox&.active? || dialogflow_active?
  end

  private

  def dialogflow_active?
    hooks.exists?(app_id: %w[dialogflow], status: 'enabled')
  end
end
