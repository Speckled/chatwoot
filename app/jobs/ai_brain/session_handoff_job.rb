# Tells the backend that a human has the conversation, after a failed turn or a receptionist taking it over. Otherwise
# it keeps nudging the patient and closes the session for inactivity while a receptionist is answering.
class AiBrain::SessionHandoffJob < ApplicationJob
  queue_as :medium

  def perform(conversation_id, reason)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation

    conversation.with_lock do
      # A retry can run after a receptionist has handed the conversation back to the bot or resolved it.
      next unless conversation.ai_brain_conversation&.state == 'human'

      status, = AiBrain::Client.new.post("conversations/#{conversation.id}/session/handoff", { reason: reason })
      raise AiBrain::Client::UnavailableError, "Handing off the session failed with HTTP #{status}" unless status == 204
    end
  end
end
