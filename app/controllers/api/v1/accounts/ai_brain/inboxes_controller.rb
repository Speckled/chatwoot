class Api::V1::Accounts::AiBrain::InboxesController < Api::V1::Accounts::AiBrain::BaseController
  def index
    render json: Current.account.inboxes.includes(:ai_brain_inbox, :channel).order(:name).map { |inbox| serialize_inbox(inbox) }
  end

  # Creates a local-only WhatsApp inbox (provider: 'test') for the AI Brain test lab.
  # It behaves like a regular WhatsApp inbox but never calls Meta / 360Dialog.
  def create
    name = params.require(:name).to_s.strip
    phone_number = normalize_phone(params.require(:phone_number))
    return render json: { error: I18n.t('ai_brain.errors.invalid_phone') }, status: :unprocessable_entity if phone_number.blank?

    inbox = ActiveRecord::Base.transaction do
      channel = Channel::Whatsapp.create!(account: Current.account, phone_number: phone_number, provider: 'test',
                                          provider_config: { 'source' => 'ai_brain_test' })
      created = Current.account.inboxes.create!(name: name.presence || "WhatsApp #{phone_number}", channel: channel)
      created.inbox_members.find_or_create_by!(user: Current.user)
      Current.account.ai_brain_inboxes.create!(inbox: created, active: true)
      created
    end

    render json: serialize_inbox(inbox.reload), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def update
    inbox = Current.account.inboxes.find(params[:inbox_id])
    active = ActiveModel::Type::Boolean.new.cast(params.fetch(:active, true))
    link = Current.account.ai_brain_inboxes.find_or_initialize_by(inbox: inbox)
    link.update!(active: active)
    render json: { active: link.active? }
  end

  def destroy
    inbox = Current.account.inboxes.find(params[:inbox_id])
    inbox.ai_brain_inbox&.destroy!
    head :no_content
  end

  private

  def serialize_inbox(inbox)
    channel = inbox.channel
    {
      id: inbox.id,
      name: inbox.name,
      channelType: inbox.channel_type,
      phoneNumber: channel.try(:phone_number),
      provider: channel.try(:provider),
      aiBrainInbox: inbox.ai_brain_inbox && { active: inbox.ai_brain_inbox.active? }
    }
  end

  def normalize_phone(value)
    digits = value.to_s.gsub(/\D/, '')
    digits.match?(/\A[1-9]\d{1,14}\z/) ? "+#{digits}" : nil
  end
end
