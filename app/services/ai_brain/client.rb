class AiBrain::Client
  class UnavailableError < StandardError; end

  def initialize(account_id)
    @account_id = account_id
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

  def execute(agent_id:, conversation_display_id:, message_id:)
    post("agents/#{agent_id}/execute", { chatwootConversationId: conversation_display_id, chatwootMessageId: message_id })
  end

  private

  def request(verb, path, params: nil, body: nil)
    response = connection.run_request(verb, "/api/accounts/#{@account_id}/#{path}", body&.to_json, nil) do |req|
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
