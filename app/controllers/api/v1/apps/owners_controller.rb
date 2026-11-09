# Changes the AI Brain owner assistant makes on the owner's behalf, once the owner has confirmed them.
class Api::V1::Apps::OwnersController < Api::V1::Apps::BaseController
  before_action :fetch_owner

  # Brings someone into the owner's account, as an agent or an administrator, and into a team when one is given: an
  # existing member is reused, anyone else is invited by email.
  def create_user
    error = create_user_error
    return render json: { error: error }, status: :unprocessable_entity if error

    user = @owner.account.users.from_email(params[:email])
    invited = user.nil?
    user ||= invite_user
    add_to_team(user) if params[:teamId].present?
    store_whatsapp_number(user)
    render json: { userId: user.id, invited: invited }
  rescue AgentBuilder::LimitExceededError, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # Edits someone in the owner's account: name, email, WhatsApp number, teams and role. A new email goes through
  # Chatwoot's reconfirmation before it is used.
  def update_user
    error = update_user_error
    return render json: { error: error }, status: :unprocessable_entity if error

    ActiveRecord::Base.transaction do
      apply_user_changes
      apply_membership_changes
    end
    render json: user_payload
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  # Takes someone out of the owner's account, as removing an agent in the settings does. The AI Brain keeps their record,
  # marked inactive.
  def remove_user
    error = removal_error
    return render json: { error: error }, status: :unprocessable_entity if error

    @account_user.destroy!
    DeleteObjectJob.perform_later(@user) if @user.reload.account_users.blank?
    render json: { userId: @user.id, removed: true }
  end

  # Sends the owner a WhatsApp text the AI Brain starts on its own, such as the confirmation that an account got connected.
  # Owner conversations never exist in Chatwoot, so it goes straight through the provider, like the assistant's replies.
  def create_message
    return render json: { error: 'text is required' }, status: :unprocessable_entity if params[:text].blank?

    inbox = owner_inbox
    return render json: { error: 'The account has no AI Brain WhatsApp inbox' }, status: :unprocessable_entity unless inbox

    sent = inbox.channel.provider_service.send_text(@owner.phone_number.delete('+'), params[:text])
    return render json: { error: 'WhatsApp did not accept the message' }, status: :bad_gateway unless sent

    render json: { inboxId: inbox.id }
  end

  private

  def fetch_owner
    @owner = AiBrainOwner.find_by(user_id: params[:user_id])
    render json: { error: 'Owner not found' }, status: :not_found unless @owner&.administrator?
  end

  # The inbox the owner wrote to when it is still one of the account's AI Brain WhatsApp inboxes, else the first of them.
  def owner_inbox
    inboxes = @owner.account.inboxes.where(channel_type: 'Channel::Whatsapp').order(:id).select(&:ai_brain_active?)
    inboxes.find { |inbox| inbox.id == params[:inboxId].to_i } || inboxes.first
  end

  # The user being changed, who must belong to the owner's account.
  def fetch_account_user
    @account_user = @owner.account.account_users.find_by(user_id: params[:chatwoot_user_id])
    @user = @account_user&.user
  end

  def update_user_error
    return 'User not found' unless fetch_account_user

    role_error || whatsapp_error || team_error
  end

  def role_error
    return if params[:role].blank?
    return 'The role must be agent or administrator' unless AccountUser.roles.key?(params[:role].to_s)

    # The owner stays an administrator, so the account always keeps one.
    'The owner cannot change their own role' if @user.id == @owner.user_id
  end

  def whatsapp_error
    I18n.t('ai_brain.errors.invalid_phone') if params.key?(:whatsAppNumber) && whatsapp_number == :invalid
  end

  def team_error
    'A team does not exist in this account' if add_teams.size != team_ids(:addTeamIds).size || remove_teams.size != team_ids(:removeTeamIds).size
  end

  # The owner stays, so the account always keeps an administrator.
  def removal_error
    return 'User not found' unless fetch_account_user

    'The owner cannot remove themself' if @user.id == @owner.user_id
  end

  def apply_user_changes
    @user.display_name = params[:displayName].to_s.strip.presence if params.key?(:displayName)
    @user.email = params[:email].to_s.strip if params[:email].present?
    @user.custom_attributes = @user.custom_attributes.merge('whatsapp_number' => whatsapp_number).compact if params.key?(:whatsAppNumber)
    @user.save!
  end

  # The role and teams in the owner's account.
  def apply_membership_changes
    @account_user.update!(role: params[:role]) if params[:role].present?
    add_teams.each { |team| team.add_members([@user.id]) unless team.members.exists?(@user.id) }
    remove_teams.each { |team| team.remove_members([@user.id]) }
  end

  # Nil clears the number; :invalid rejects the request.
  def whatsapp_number
    number = params[:whatsAppNumber].to_s.strip
    return nil if number.blank?

    canonical = AiBrainOwner.canonical_phone_number(number)
    canonical&.match?(/\A\+[1-9]\d{7,14}\z/) ? canonical : :invalid
  end

  def team_ids(key)
    Array(params[key]).map(&:to_i).uniq
  end

  def add_teams
    @add_teams ||= @owner.account.teams.where(id: team_ids(:addTeamIds)).to_a
  end

  def remove_teams
    @remove_teams ||= @owner.account.teams.where(id: team_ids(:removeTeamIds)).to_a
  end

  def user_payload
    @user.reload
    { userId: @user.id, displayName: @user.display_name, email: @user.email, unconfirmedEmail: @user.unconfirmed_email,
      whatsAppNumber: @user.custom_attributes['whatsapp_number'], teamIds: @user.teams.where(account_id: @owner.account_id).pluck(:id),
      role: @account_user.reload.role }
  end

  def store_whatsapp_number(user)
    number = AiBrainOwner.canonical_phone_number(params[:whatsAppNumber])
    return if number.blank?

    user.update!(custom_attributes: user.custom_attributes.merge('whatsapp_number' => number))
  end

  def create_user_error
    return 'name and email are required' if params[:name].blank? || params[:email].blank?
    return 'The role must be agent or administrator' unless AccountUser.roles.key?(new_user_role)

    'The team does not exist in this account' if params[:teamId].present? && !@owner.account.teams.exists?(params[:teamId])
  end

  def invite_user
    AgentBuilder.new(email: params[:email], name: params[:name], inviter: @owner.user, account: @owner.account, role: new_user_role).perform
  end

  def add_to_team(user)
    team = @owner.account.teams.find(params[:teamId])
    team.add_members([user.id]) unless team.members.exists?(user.id)
  end

  def new_user_role
    params[:role].presence || 'agent'
  end
end
