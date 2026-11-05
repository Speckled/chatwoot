# Connects the clinic's Mercado Pago account, or a professional's own, through the backend's OAuth round trip; the
# backend sends the browser back to the services page. :user_id is the AI Brain user id, not the Chatwoot one.
class Api::V1::Accounts::AiBrain::MercadoPagoController < Api::V1::Accounts::AiBrain::BaseController
  def authorization_url
    render_upstream(client.get('services/mercado-pago/auth/url', redirect: false, returnUrl: return_url))
  end

  def professional_authorization_url
    render_upstream(client.get("users/#{uuid_param!(:user_id)}/services/mercado-pago/auth/url", redirect: false, returnUrl: return_url))
  end

  def destroy
    render_upstream(client.delete('services/mercado-pago'))
  end

  def destroy_professional
    render_upstream(client.delete("users/#{uuid_param!(:user_id)}/services/mercado-pago"))
  end

  private

  def return_url
    "#{ENV.fetch('FRONTEND_URL').chomp('/')}/app/accounts/#{Current.account.id}/ai-brain/services"
  end
end
