# Sends the messages the AI Brain adds after a reply, such as a Pix key, one at a time and a few seconds apart. Chatwoot
# sends each message in a job of its own, so messages created together can reach WhatsApp out of order.
class AiBrain::FollowUpJob < ApplicationJob
  queue_as :medium

  def self.schedule(conversation_id, source_message_id, session_id, follow_ups)
    set(wait: 2.seconds).perform_later(conversation_id, source_message_id, session_id, follow_ups)
  end

  # Takes no conversation lock: a turn for the patient's next message holds it until that turn's reply is sent, and these
  # messages belong before that reply.
  def perform(conversation_id, source_message_id, session_id, follow_ups)
    follow_up, *rest = follow_ups
    conversation = Conversation.find(conversation_id)
    delivery = AiBrain::Delivery.new(conversation: conversation, client: AiBrain::Client.new, source_message_id: source_message_id,
                                     session_id: session_id)
    # A failed confirmation takes the message back, so the retry does not send it twice.
    ActiveRecord::Base.transaction { delivery.deliver!(follow_up.fetch('text'), follow_up.fetch('outgoingMessageId')) }
    self.class.schedule(conversation_id, source_message_id, session_id, rest) if rest.present?
  end
end
