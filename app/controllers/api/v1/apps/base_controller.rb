# Routes the AI Brain backend calls, authenticated with the shared AI_BRAIN_API_KEY.
class Api::V1::Apps::BaseController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :set_current_user
  before_action :verify_api_key!

  private

  def verify_api_key!
    expected = ENV.fetch('AI_BRAIN_API_KEY', '').to_s
    supplied = request.headers['X-Api-Key'].to_s
    return if expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, supplied)

    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
end
