class Api::V1::Accounts::AiBrain::GoogleCalendarController < Api::V1::Accounts::AiBrain::BaseController
  def authorization_url
    frontend_url = ENV.fetch('FRONTEND_URL').chomp('/')
    return_url = "#{frontend_url}/app/accounts/#{Current.account.id}/ai-brain/services"
    render_upstream(client.get('services/google-calendar/auth/url', redirect: false, returnUrl: return_url))
  end

  def destroy
    render_upstream(client.delete('services/google-calendar'))
  end
end
