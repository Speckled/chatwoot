class Api::V1::Accounts::AiBrain::BaseController < Api::V1::Accounts::BaseController
  UUID_REGEX = /\A\h{8}-(\h{4}-){3}\h{12}\z/i

  before_action -> { authorize :ai_brain, :manage? }

  rescue_from AiBrain::Client::UnavailableError do
    render json: { error: I18n.t('ai_brain.errors.unavailable') }, status: :bad_gateway
  end

  private

  def client
    @client ||= AiBrain::Client.new
  end

  def render_upstream(result)
    status, body = result
    return head :no_content if status == 204

    render json: body || {}, status: status
  end

  def uuid_param!(key = :id)
    value = params[key].to_s
    raise ActionController::BadRequest, "Invalid UUID parameter: #{key}" unless value.match?(UUID_REGEX)

    value
  end
end
