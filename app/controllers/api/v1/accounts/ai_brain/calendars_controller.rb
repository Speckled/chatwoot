class Api::V1::Accounts::AiBrain::CalendarsController < Api::V1::Accounts::AiBrain::BaseController
  def index
    render_upstream(client.get('calendars'))
  end

  def user
    calendar_id = ERB::Util.url_encode(params[:calendar_id].to_s)
    render_upstream(client.put("calendars/#{calendar_id}/user", { userId: params[:userId].presence }))
  end
end
