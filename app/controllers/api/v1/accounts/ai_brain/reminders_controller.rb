class Api::V1::Accounts::AiBrain::RemindersController < Api::V1::Accounts::AiBrain::BaseController
  def index
    render_upstream(client.get('reminders'))
  end

  def show
    render_upstream(client.get("reminders/#{uuid_param!}"))
  end

  def create
    render_upstream(client.post('reminders', reminder_params))
  end

  def update
    render_upstream(client.put("reminders/#{uuid_param!}", reminder_params))
  end

  def destroy
    render_upstream(client.delete("reminders/#{uuid_param!}"))
  end

  def enabled
    render_upstream(client.put("reminders/#{uuid_param!}/enabled", { isEnabled: ActiveModel::Type::Boolean.new.cast(params[:isEnabled]) }))
  end

  def deliveries
    render_upstream(client.get("reminders/#{uuid_param!}/deliveries", params.permit(:limit).to_h.compact))
  end

  # Plans one occurrence now; the AI Brain sends it within a minute.
  def run_now
    render_upstream(client.post("reminders/#{uuid_param!}/run-now"))
  end

  def placeholders
    render_upstream(client.get('reminders/placeholders'))
  end

  private

  def reminder_params
    params.require(:reminder).permit(
      :name, :isEnabled,
      target: [:type, :chatwootContactId, :phoneNumber, :name, :userId, :teamId],
      channel: [:inboxId, :aiReplies, { template: [:name, :language, :category, { bodyParameters: [] }] }],
      schedule: [:type, :at, :timeOfDay, :daysBefore, :minutesBefore, { days: [], calendarIds: [] }],
      content: [:kind, :text, :emptyText]
    ).to_h
  end
end
