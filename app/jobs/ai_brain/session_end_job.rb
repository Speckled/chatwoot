# Ends the AI Brain session of a resolved conversation and hands the conversation back to the bot, so the patient's
# next message starts a new session instead of colliding with the old one. When the bot resolved the conversation
# itself, the backend has already ended the session and this changes nothing.
class AiBrain::SessionEndJob < ApplicationJob
  queue_as :medium

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation

    conversation.with_lock do
      # The patient's next message reopens the conversation, and its session is then in use again.
      next unless conversation.resolved?

      status, = AiBrain::Client.new.post("conversations/#{conversation.id}/session/end")
      raise AiBrain::Client::UnavailableError, "Ending the session failed with HTTP #{status}" unless status == 204

      conversation.ai_brain_conversation&.reset_to_bot!
    end
  end
end
