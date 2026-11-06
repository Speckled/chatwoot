# What the AI Brain's staff layer changes in an account: staff contacts, flagged before the person ever writes, and the
# private channel (ai_brain_owners) for administrators who talk to their assistant on WhatsApp.
class Api::V1::Apps::StaffController < Api::V1::Apps::BaseController
  before_action :fetch_account

  # Finds or creates the contact for the number and marks it staff in every AI Brain WhatsApp inbox of the account, so
  # the person's conversations there are staff-only and the AI never answers them as a patient.
  def create_contact
    phone_number = AiBrainOwner.canonical_phone_number(params[:phoneNumber])
    return render json: { error: I18n.t('ai_brain.errors.invalid_phone') }, status: :unprocessable_entity unless valid_phone?(phone_number)

    contact = @account.contacts.find_by(phone_number: phone_number) ||
              @account.contacts.create!(name: params[:name].to_s.strip.presence || phone_number, phone_number: phone_number)
    render json: { contactId: contact.id, inboxIds: flag_staff!(contact) }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  # Registers the user for the private channel with their WhatsApp number.
  def upsert_assistant
    user = @account.users.find_by(id: params[:user_id])
    return render json: { error: 'User not found in the account' }, status: :not_found unless user

    owner = @account.ai_brain_owners.find_or_initialize_by(user: user)
    owner.phone_number = params[:phoneNumber]
    owner.save!
    render json: { userId: user.id, phoneNumber: owner.phone_number }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def destroy_assistant
    @account.ai_brain_owners.where(user_id: params[:user_id]).destroy_all
    head :no_content
  end

  private

  def fetch_account
    @account = Account.find_by(id: params[:account_id])
    render json: { error: 'Account not found' }, status: :not_found unless @account
  end

  def flag_staff!(contact)
    inbox_ids = @account.inboxes.where(channel_type: 'Channel::Whatsapp').select(&:ai_brain_active?).map(&:id)
    attributes = contact.additional_attributes || {}
    flagged = Array(attributes[AiBrainStaffConversation::STAFF_INBOXES_KEY]) | inbox_ids
    contact.update!(additional_attributes: attributes.merge(AiBrainStaffConversation::STAFF_INBOXES_KEY => flagged))
    flagged
  end

  def valid_phone?(phone_number)
    phone_number&.match?(/\A\+[1-9]\d{7,14}\z/)
  end
end
