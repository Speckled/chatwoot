# Mercado Pago charges the AI Brain made for patients, and refunds of paid ones.
class Api::V1::Accounts::AiBrain::PaymentsController < Api::V1::Accounts::AiBrain::BaseController
  def index
    status, body = client.get('payments', params.permit(:from, :to, :status, :limit).to_h.compact)
    return render_upstream([status, body]) unless status == 200 && body.is_a?(Array)

    render json: with_conversation_display_ids(body)
  end

  # Returns the whole amount to the patient through Mercado Pago.
  def refund
    render_upstream(client.post("payments/#{uuid_param!}/refund"))
  end

  private

  # The backend knows Chatwoot's internal conversation id; the dashboard links by display id.
  def with_conversation_display_ids(payments)
    ids = payments.filter_map { |payment| payment['chatwootConversationId'] }
    display_ids = Current.account.conversations.where(id: ids).pluck(:id, :display_id).to_h
    payments.map { |payment| payment.merge('conversationDisplayId' => display_ids[payment['chatwootConversationId']]) }
  end
end
