# Sends a message the AI Brain scheduled, such as a reminder, to someone through one of the account's WhatsApp or
# Instagram inboxes. It finds or starts their conversation there and posts as the AI Brain bot, so the message and any
# reply show in Chatwoot. A retry with the same outgoingId returns the message already posted instead of sending again.
# Messages to staff are flagged so that only administrators see them, and the AI never answers them.
class Api::V1::Apps::InboxMessagesController < Api::V1::Apps::BaseController
  class InvalidRequestError < StandardError; end

  SUPPORTED_CHANNELS = %w[Channel::Whatsapp Channel::Instagram].freeze

  rescue_from InvalidRequestError do |error|
    render json: { error: error.message }, status: :unprocessable_entity
  end

  before_action :fetch_inbox
  before_action :validate_request
  before_action :validate_template, if: -> { template.present? }

  def create
    contact = find_or_create_contact
    flag_staff_contact!(contact) if staff?
    contact_inbox = find_or_create_contact_inbox(contact)
    conversation = find_or_start_conversation(contact_inbox)
    message, duplicate = post_message(conversation, contact_inbox)

    render json: { chatwootMessageId: message.id, chatwootConversationId: conversation.id,
                   chatwootConversationDisplayId: conversation.display_id, contactId: contact.id, duplicate: duplicate }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def fetch_inbox
    @inbox = Inbox.find_by(id: params[:inbox_id])
    render json: { error: 'Inbox not found' }, status: :not_found unless @inbox
  end

  def validate_request
    raise InvalidRequestError, 'Only WhatsApp and Instagram inboxes send these messages' unless SUPPORTED_CHANNELS.include?(@inbox.channel_type)
    raise InvalidRequestError, 'outgoingId and text are required' if outgoing_id.blank? || params[:text].blank?
  end

  def validate_template
    raise InvalidRequestError, 'Templates are sent only through WhatsApp inboxes' unless whatsapp?
    raise InvalidRequestError, 'A template needs a name and a language' if template[:name].blank? || template[:language].blank?
  end

  def find_or_create_contact
    return find_contact_by_id if params.dig(:to, :contactId).present?

    phone_number = AiBrainOwner.canonical_phone_number(params.dig(:to, :phoneNumber))
    raise InvalidRequestError, 'A valid phone number is required' unless phone_number&.match?(/\A\+[1-9]\d{7,14}\z/)

    account.contacts.find_by(phone_number: phone_number) ||
      account.contacts.create!(name: params.dig(:to, :name).to_s.strip.presence || phone_number, phone_number: phone_number)
  end

  def find_contact_by_id
    contact = account.contacts.find_by(id: params.dig(:to, :contactId))
    raise InvalidRequestError, 'The contact does not exist in this account' unless contact
    raise InvalidRequestError, 'The contact has no phone number' if whatsapp? && contact.phone_number.blank?

    contact
  end

  def flag_staff_contact!(contact)
    return if Conversation.ai_brain_staff_contact?(contact, @inbox.id)

    attributes = contact.additional_attributes || {}
    inbox_ids = Array(attributes[AiBrainStaffConversation::STAFF_INBOXES_KEY]) | [@inbox.id]
    contact.update!(additional_attributes: attributes.merge(AiBrainStaffConversation::STAFF_INBOXES_KEY => inbox_ids))
  end

  # The contact's own thread in the inbox comes first: its source id is the number WhatsApp reported, which can differ
  # from the stored phone number, and their replies arrive there. Instagram cannot message someone who never wrote.
  def find_or_create_contact_inbox(contact)
    existing = @inbox.contact_inboxes.where(contact: contact).order(updated_at: :desc).first
    return existing if existing
    raise InvalidRequestError, 'Instagram can only message someone who has written to this inbox' unless whatsapp?

    ContactInboxBuilder.new(contact: contact, inbox: @inbox).perform
  end

  def find_or_start_conversation(contact_inbox)
    active = contact_inbox.conversations.where.not(status: :resolved).reorder(:created_at).last
    # Reloaded because a new conversation copies its trigger-set display id in a way that leaves it marked as changed,
    # and a changed record cannot be locked.
    conversation = active || ConversationBuilder.new(params: ActionController::Parameters.new, contact_inbox: contact_inbox).perform.reload
    conversation.with_lock do
      mark_staff!(conversation) if staff?
      # Whoever handles a conversation already under way keeps it; a new or resolved one is handed over here.
      hand_over!(conversation) unless active
    end
    conversation
  end

  def mark_staff!(conversation)
    return if conversation.ai_brain_staff?

    audience = { AiBrainStaffConversation::AUDIENCE_KEY => AiBrainStaffConversation::STAFF_AUDIENCE }
    conversation.update!(additional_attributes: (conversation.additional_attributes || {}).merge(audience))
  end

  # The AI answers a client's reply when the message asks for it. Otherwise receptionists do, under Open.
  def hand_over!(conversation)
    return keep_for_administrators!(conversation) if staff?
    return hand_to_ai!(conversation) if ai_replies?

    human_state(conversation).update!(state: 'human')
    conversation.open! unless conversation.open?
  end

  # Staff conversations are pending on every inbox, as they start on the inboxes the AI serves. Agents are never shown,
  # assigned or notified about them whatever the status: the finder, the policy and auto-assignment leave them out.
  def keep_for_administrators!(conversation)
    human_state(conversation).update!(state: 'human')
    conversation.pending! unless conversation.pending?
  end

  def hand_to_ai!(conversation)
    conversation.ai_brain_conversation&.reset_to_bot!
    conversation.pending! if @inbox.ai_brain_active? && !conversation.pending?
  end

  def human_state(conversation)
    conversation.ai_brain_conversation || conversation.build_ai_brain_conversation(account: conversation.account)
  end

  def post_message(conversation, contact_inbox)
    conversation.with_lock do
      sent = Message.where(conversation_id: contact_inbox.conversations.select(:id))
                    .find_by("additional_attributes->>'ai_brain_outgoing_id' = ?", outgoing_id)
      next [sent, true] if sent

      [conversation.messages.create!(message_attributes(conversation)), false]
    end
  end

  def message_attributes(conversation)
    {
      account: conversation.account,
      inbox: conversation.inbox,
      message_type: :outgoing,
      content: params[:text].to_s,
      sender: AiBrain::BotSender.for(conversation.account),
      additional_attributes: { 'ai_brain_outgoing_id' => outgoing_id, 'ai_brain_reminder' => true,
                               'template_params' => template_params }.compact
    }
  end

  # The shape Whatsapp::TemplateProcessorService reads: body parameters numbered from 1, in order.
  def template_params
    return if template.blank?

    body = Array(template[:bodyParameters]).each_with_index.to_h { |value, index| [(index + 1).to_s, value.to_s] }
    { 'name' => template[:name], 'language' => template[:language], 'category' => template[:category].presence,
      'processed_params' => { 'body' => body } }.compact
  end

  def account
    @inbox.account
  end

  def outgoing_id
    params[:outgoingId].to_s
  end

  def template
    @template ||= params[:template].presence
  end

  def whatsapp?
    @inbox.channel_type == 'Channel::Whatsapp'
  end

  def staff?
    params[:audience] == 'staff'
  end

  def ai_replies?
    ActiveModel::Type::Boolean.new.cast(params.fetch(:aiReplies, true))
  end
end
