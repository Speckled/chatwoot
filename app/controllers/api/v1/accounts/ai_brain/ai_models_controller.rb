class Api::V1::Accounts::AiBrain::AiModelsController < Api::V1::Accounts::AiBrain::BaseController
  def providers
    render_upstream(client.get('ai/providers'))
  end

  # The backend caches the provider's list for an hour; refresh=true fetches it again.
  def models
    provider = ERB::Util.url_encode(params[:provider].to_s)
    render_upstream(client.get("ai/providers/#{provider}/models", params.permit(:refresh).to_h.compact))
  end
end
