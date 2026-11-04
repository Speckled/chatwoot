class Api::V1::Accounts::AiBrain::UsersController < Api::V1::Accounts::AiBrain::BaseController
  def index
    render_upstream(client.get('users', params.permit(:calendar).to_h.compact))
  end

  # Edits a member of a team that requires a calendar. A new email goes through Chatwoot's reconfirmation before it is used.
  def update
    # A subquery rather than a join with DISTINCT: users has json columns, which Postgres cannot compare.
    calendar_members = TeamMember.joins(:team).where(teams: { account_id: Current.account.id, requires_calendar: true }).select(:user_id)
    user = Current.account.users.where(id: calendar_members).find(params[:id])
    whatsapp_number = canonical_whatsapp_number
    return render json: { error: I18n.t('ai_brain.errors.invalid_phone') }, status: :unprocessable_entity if whatsapp_number == :invalid

    user.display_name = params[:displayName].to_s.strip.presence if params.key?(:displayName)
    user.email = params[:email].to_s.strip if params.key?(:email)
    user.custom_attributes = user.custom_attributes.merge('whatsapp_number' => whatsapp_number).compact if params.key?(:whatsAppNumber)
    user.save!
    render json: { id: user.id, displayName: user.display_name, email: user.email, unconfirmedEmail: user.unconfirmed_email,
                   whatsAppNumber: user.custom_attributes['whatsapp_number'] }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def canonical_whatsapp_number
    number = params[:whatsAppNumber].to_s.strip
    return nil if number.blank?

    canonical = AiBrainOwner.canonical_phone_number(number)
    canonical&.match?(/\A\+[1-9]\d{7,14}\z/) ? canonical : :invalid
  end
end
