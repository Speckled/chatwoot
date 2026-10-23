class Api::V1::Accounts::AiBrain::CalendarsController < Api::V1::Accounts::AiBrain::BaseController
  def index
    render_upstream(client.get('calendars'))
  end
end
