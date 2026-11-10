# Runs one turn of the admin assistant for the dashboard drawer. A turn with tool calls takes longer than a web request
# may, so the drawer asks for the reply by its ID until this job stores it. The arguments stay out of the logs because
# they carry the message text.
class AiBrain::AdminAssistantJob < ApplicationJob
  REPLY_TTL = 10.minutes

  queue_as :high
  self.log_arguments = false

  def self.reply_key(user_id, request_id)
    "ai_brain:admin_assistant:#{user_id}:#{request_id}"
  end

  # The stored reply: nil while the turn runs, then the backend's status and body.
  def self.reply(user_id, request_id)
    stored = Redis::Alfred.get(reply_key(user_id, request_id))
    stored && JSON.parse(stored)
  end

  def perform(user_id, request_id, body)
    status, result = AiBrain::Client.new.post('owner/messages', body)
    store(user_id, request_id, status, result)
  rescue AiBrain::Client::UnavailableError => e
    Rails.logger.warn("AI Brain admin assistant turn failed: #{e.message}")
    # No text of its own: the drawer shows its translated error.
    store(user_id, request_id, 502, {})
  end

  private

  def store(user_id, request_id, status, result)
    Redis::Alfred.setex(self.class.reply_key(user_id, request_id), { status: status, body: result }.to_json, REPLY_TTL)
  end
end
