class Api::V1::Accounts::AiBrain::ServicesController < Api::V1::Accounts::AiBrain::BaseController
  def index
    render_upstream(client.get('services'))
  end
end
