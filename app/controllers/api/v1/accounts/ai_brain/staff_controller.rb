# The clinic's staff as the AI Brain keeps it: Chatwoot users and people without a login, with their capabilities.
# Changes name the current user, since only owners of the clinic change capabilities.
class Api::V1::Accounts::AiBrain::StaffController < Api::V1::Accounts::AiBrain::BaseController
  def index
    render_upstream(client.get('users'))
  end

  def create
    body = params.permit(:name, :whatsAppNumber, :email, :bookable, :responder).to_h
    render_upstream(client.post('users/providers', body.merge(accountId: Current.account.id)))
  end

  def capabilities
    body = params.permit(:isOwner, :isResponder, :assistantAccess, :bookable).to_h
    render_upstream(client.put("users/#{uuid_param!}/capabilities", body.merge(actingChatwootUserId: Current.user.id)))
  end

  # Only people without a login; Chatwoot users are removed in the agents settings.
  def destroy
    render_upstream(client.delete("users/#{uuid_param!}"))
  end
end
