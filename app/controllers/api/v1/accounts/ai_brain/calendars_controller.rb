class Api::V1::Accounts::AiBrain::CalendarsController < Api::V1::Accounts::AiBrain::BaseController
  def index
    render_upstream(client.get('calendars'))
  end

  # Creates a Google calendar for a member of a team that requires one and links it to them; the name defaults to theirs.
  def create
    render_upstream(client.post('calendars', { userId: uuid_param!(:userId), summary: params[:summary].presence }.compact))
  end

  def user
    calendar_id = ERB::Util.url_encode(params[:calendar_id].to_s)
    render_upstream(client.put("calendars/#{calendar_id}/user", { userId: params[:userId].presence }))
  end
end
