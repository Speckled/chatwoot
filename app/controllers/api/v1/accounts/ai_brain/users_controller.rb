class Api::V1::Accounts::AiBrain::UsersController < Api::V1::Accounts::AiBrain::BaseController
  def index
    render_upstream(client.get('users', params.permit(:team).to_h.compact))
  end
end
