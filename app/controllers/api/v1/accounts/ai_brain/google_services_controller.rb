# The route constraint limits :service to the Google services the AI Brain can connect.
class Api::V1::Accounts::AiBrain::GoogleServicesController < Api::V1::Accounts::AiBrain::BaseController
  def authorization_url
    frontend_url = ENV.fetch('FRONTEND_URL').chomp('/')
    return_url = "#{frontend_url}/app/accounts/#{Current.account.id}/ai-brain/services"
    render_upstream(client.get("services/#{params[:service]}/auth/url", redirect: false, returnUrl: return_url))
  end

  def destroy
    render_upstream(client.delete("services/#{params[:service]}"))
  end
end
