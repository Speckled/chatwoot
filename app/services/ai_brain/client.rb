class AiBrain::Client
  class UnavailableError < StandardError; end

  attr_reader :app_id

  def initialize(app_id = nil)
    @app_id = app_id.is_a?(String) && app_id.present? ? app_id : ENV.fetch('AI_BRAIN_APP_ID', 'chatwoot-main')
  end

  def get(path, params = {})
    request(:get, path, params: params)
  end

  def post(path, body = {})
    request(:post, path, body: body)
  end

  def put(path, body = {})
    request(:put, path, body: body)
  end

  def delete(path)
    request(:delete, path)
  end

  def send_session_message(session_id:, phone_number:, conversation_id:, message_id:, contact_id: nil)
    post('sessions/messages', {
      sessionId: session_id,
      phoneNumber: phone_number,
      chatwootConversationId: conversation_id,
      chatwootMessageId: message_id,
      chatwootContactId: contact_id
    })
  end

  def confirm_delivery(session_id:, outgoing_message_id:, chatwoot_message_id: nil, status: 1, error_reason: nil)
    post("sessions/#{session_id}/messages/#{outgoing_message_id}/confirm", {
      chatwootMessageId: chatwoot_message_id,
      status: status,
      errorReason: error_reason,
      deliveredAt: Time.current.iso8601
    })
  end

  private

  def request(verb, path, params: nil, body: nil)
    response = connection.run_request(verb, "/api/apps/#{@app_id}/#{path}", body&.to_json, nil) do |req|
      req.params.update(params) if params.present?
    end
    [response.status, response.body.present? ? JSON.parse(response.body) : nil]
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError, JSON::ParserError => e
    raise UnavailableError, e.message
  end

  def connection
    @connection ||= Faraday.new(url: ENV.fetch('AI_BRAIN_API_URL', 'http://agent-api:8080')) do |faraday|
      faraday.headers['X-Api-Key'] = ENV.fetch('AI_BRAIN_API_KEY')
      faraday.headers['Content-Type'] = 'application/json'
      faraday.options.timeout = 60
    end
  end
end
