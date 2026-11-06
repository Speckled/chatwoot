# The admin assistant in the dashboard drawer: the same assistant and conversation as the owner's WhatsApp, as the
# current administrator.
class Api::V1::Accounts::AiBrain::AdminAssistantController < Api::V1::Accounts::AiBrain::BaseController
  def index
    render_upstream(client.get("owner/#{Current.user.id}/messages", params.permit(:limit).to_h.compact))
  end

  def create
    text = params.require(:text).to_s.strip
    return render json: { error: I18n.t('ai_brain.errors.empty_message') }, status: :unprocessable_entity if text.blank?

    render_upstream(client.post('owner/messages', ownerUserId: Current.user.id, phoneNumber: concurrency_phone, text: text,
                                                  whatsAppMessageId: "dashboard-#{SecureRandom.uuid}", messageType: 'text',
                                                  channel: 'dashboard'))
  end

  private

  # The backend answers one message per number at a time; the WhatsApp number when the user has one, so a message from
  # the phone and one from the drawer never run together.
  def concurrency_phone
    Current.account.ai_brain_owners.find_by(user: Current.user)&.phone_number || "dashboard-user-#{Current.user.id}"
  end
end
