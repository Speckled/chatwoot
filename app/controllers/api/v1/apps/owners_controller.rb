# Changes the AI Brain owner assistant makes on the owner's behalf, once the owner has confirmed them.
class Api::V1::Apps::OwnersController < Api::V1::Apps::BaseController
  before_action :fetch_owner

  # Brings someone into a team of the owner's account: an existing member is reused, anyone else is invited by email.
  def create_user
    name, email = params.values_at(:name, :email)
    return render json: { error: 'name and email are required' }, status: :unprocessable_entity if name.blank? || email.blank?

    account = @owner.account
    team = account.teams.find_by(id: params[:teamId])
    return render json: { error: 'The team does not exist in this account' }, status: :unprocessable_entity unless team

    user = account.users.from_email(email)
    invited = user.nil?
    user ||= AgentBuilder.new(email: email, name: name, inviter: @owner.user, account: account, role: :agent).perform
    team.add_members([user.id]) unless team.members.exists?(user.id)
    store_whatsapp_number(user)
    render json: { userId: user.id, invited: invited }
  rescue AgentBuilder::LimitExceededError, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_owner
    @owner = AiBrainOwner.find_by(user_id: params[:user_id])
    render json: { error: 'Owner not found' }, status: :not_found unless @owner&.administrator?
  end

  def store_whatsapp_number(user)
    number = AiBrainOwner.canonical_phone_number(params[:whatsAppNumber])
    return if number.blank?

    user.update!(custom_attributes: user.custom_attributes.merge('whatsapp_number' => number))
  end
end
