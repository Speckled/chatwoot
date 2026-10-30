# Backs the AI Brain "Test conversations" tab. It drives a local-only WhatsApp inbox
# (Channel::Whatsapp with provider 'test') by creating regular Chatwoot conversations and
# messages, so AiBrainListener / AiBrain::ResponseJob and the agent API process them exactly
# like real WhatsApp traffic.
class Api::V1::Accounts::AiBrain::TestConversationsController < Api::V1::Accounts::AiBrain::BaseController
  SENDER_ROLES = %w[client secretary].freeze
  MESSAGE_LIMIT = 200

  before_action :fetch_conversation, only: [:show, :messages]

  def index
    inbox = test_inbox!(params.require(:inbox_id))
    conversations = inbox.conversations.includes(:contact, :ai_brain_conversation)
                         .reorder(last_activity_at: :desc).limit(50).to_a
    recent_messages = recent_messages_for(conversations.map(&:id))
    ai_enabled = inbox.ai_brain_active?
    render json: conversations.map { |conversation|
      conversation_summary(conversation, last_message: recent_messages[conversation.id], ai_enabled: ai_enabled)
    }
  end

  def contacts
    scope = Current.account.contacts.where.not(phone_number: [nil, ''])
    query = params[:q].to_s.strip
    if query.present?
      like = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      scope = scope.where('contacts.name ILIKE :like OR contacts.phone_number ILIKE :like', like: like)
    end
    render json: scope.order(updated_at: :desc).limit(25).map { |contact| contact_payload(contact) }
  end

  def show
    render json: conversation_detail(@conversation)
  end

  def create
    inbox = test_inbox!(params.require(:inbox_id))
    contact = resolve_contact
    return if performed?

    contact_inbox = ContactInboxBuilder.new(contact: contact, inbox: inbox).perform
    conversation = find_or_start_conversation(inbox, contact_inbox)
    render json: conversation_detail(conversation), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def messages
    content = params[:content].to_s.strip
    role = params[:sender_role].to_s
    return render_error(I18n.t('ai_brain.errors.empty_message')) if content.blank?
    return render_error(I18n.t('ai_brain.errors.invalid_sender_role')) unless SENDER_ROLES.include?(role)

    role == 'client' ? create_client_message(content) : create_secretary_message(content)
    render json: conversation_detail(@conversation.reload), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def render_error(message, status = :unprocessable_entity)
    render json: { error: message }, status: status
  end

  # Only local test inboxes are allowed: driving a real WhatsApp inbox from here would
  # deliver AI / secretary replies to real phone numbers.
  def test_inbox!(inbox_id)
    inbox = Current.account.inboxes.find(inbox_id)
    raise ActionController::BadRequest, I18n.t('ai_brain.errors.whatsapp_inbox_required') unless test_inbox?(inbox)

    inbox
  end

  def test_inbox?(inbox)
    inbox.whatsapp? && inbox.channel.try(:test_provider?)
  end

  def fetch_conversation
    @conversation = Current.account.conversations.find_by!(display_id: params[:id])
    raise ActionController::BadRequest, I18n.t('ai_brain.errors.whatsapp_inbox_required') unless test_inbox?(@conversation.inbox)
  end

  def resolve_contact
    if params[:contact_id].present?
      contact = Current.account.contacts.find(params[:contact_id])
      return contact if contact.phone_number.present?

      return render_error(I18n.t('ai_brain.errors.invalid_phone'))
    end

    return render_error(I18n.t('ai_brain.errors.contact_required')) if params[:phone_number].blank?

    phone_number = normalize_phone(params[:phone_number])
    return render_error(I18n.t('ai_brain.errors.invalid_phone')) if phone_number.blank?

    Current.account.contacts.find_by(phone_number: phone_number) ||
      Current.account.contacts.create!(name: params[:contact_name].to_s.strip.presence || phone_number, phone_number: phone_number)
  end

  def normalize_phone(value)
    digits = value.to_s.gsub(/\D/, '')
    digits.match?(/\A[1-9]\d{1,14}\z/) ? "+#{digits}" : nil
  end

  def find_or_start_conversation(inbox, contact_inbox)
    open_conversations = contact_inbox.conversations.where.not(status: :resolved)
    if ActiveModel::Type::Boolean.new.cast(params[:force_new])
      open_conversations.find_each { |conversation| close_conversation(conversation) }
    else
      existing = open_conversations.reorder(:created_at).last
      return existing if existing
    end

    conversation = ConversationBuilder.new(params: ActionController::Parameters.new, contact_inbox: contact_inbox).perform
    conversation.pending! if inbox.ai_brain_active? && conversation.open?
    conversation
  end

  # Mirrors a session ending: closes the agent API session (so a new conversation for the same
  # phone number gets a fresh session) and resolves the Chatwoot conversation.
  def close_conversation(conversation)
    conversation.with_lock do
      state = conversation.ai_brain_conversation
      if state&.session_id.present?
        begin
          client.post("sessions/#{state.session_id}/close", { reason: 'AI Brain test lab: new conversation started' })
        rescue StandardError => e
          Rails.logger.warn("AI Brain test lab failed to close upstream session #{state.session_id}: #{e.message}")
        end
      end
      state&.reset_to_bot!
      conversation.resolved!
    end
  end

  def create_client_message(content)
    @conversation.with_lock do
      reactivate_bot_conversation
      @conversation.messages.create!(
        account: @conversation.account,
        inbox: @conversation.inbox,
        message_type: :incoming,
        content: content,
        sender: @conversation.contact,
        source_id: "wamid.test.#{SecureRandom.hex(8)}"
      )
    end
  end

  # A real incoming WhatsApp message on a bot-owned conversation is only routed to the AI
  # while the conversation is pending. Resolved conversations are reopened by Message itself.
  def reactivate_bot_conversation
    return unless @conversation.open? && @conversation.inbox.ai_brain_active?
    return unless @conversation.ai_brain_conversation&.state.in?([nil, 'bot'])

    @conversation.pending!
  end

  # Secretary messages are plain outgoing agent messages; the AI state is left untouched.
  def create_secretary_message(content)
    @conversation.messages.create!(
      account: @conversation.account,
      inbox: @conversation.inbox,
      message_type: :outgoing,
      content: content,
      sender: Current.user
    )
  end

  def recent_messages_for(conversation_ids)
    return {} if conversation_ids.blank?

    Message.where(conversation_id: conversation_ids, message_type: [:incoming, :outgoing], private: false)
           .select('DISTINCT ON (conversation_id) *')
           .reorder(:conversation_id, created_at: :desc)
           .index_by(&:conversation_id)
  end

  def contact_payload(contact)
    { id: contact.id, name: contact.name, phoneNumber: contact.phone_number }
  end

  def ai_state_payload(conversation, ai_enabled: nil)
    state = conversation.ai_brain_conversation
    ai_active = ai_enabled.nil? ? conversation.inbox.ai_brain_active? : ai_enabled
    {
      state: state&.state || 'bot',
      sessionId: state&.session_id,
      activeWorkflow: state&.active_workflow,
      clientId: state&.client_id,
      aiEnabled: ai_active
    }
  end

  def conversation_summary(conversation, last_message: nil, ai_enabled: nil)
    last_msg = last_message || conversation.messages.where(message_type: [:incoming, :outgoing], private: false).reorder(created_at: :desc).first
    {
      id: conversation.display_id,
      status: conversation.status,
      inboxId: conversation.inbox_id,
      contact: contact_payload(conversation.contact),
      aiBrain: ai_state_payload(conversation, ai_enabled: ai_enabled),
      lastActivityAt: conversation.last_activity_at.to_i,
      lastMessage: last_msg && { content: last_msg.content, role: message_role(last_msg) }
    }
  end

  def conversation_detail(conversation)
    ai_brain = ai_state_payload(conversation).merge(review: pending_review(conversation))
    messages = conversation.messages.includes(:sender).reorder(created_at: :desc, id: :desc).limit(MESSAGE_LIMIT).to_a.reverse
    conversation_summary(conversation).merge(
      aiBrain: ai_brain,
      awaitingAi: awaiting_ai?(conversation, messages),
      messages: messages.map { |message| message_payload(message) }
    )
  end

  # True while the latest public message is from the client and the AI is expected to answer.
  def awaiting_ai?(conversation, messages)
    return false unless conversation.pending? && conversation.inbox.ai_brain_active?
    return false unless conversation.ai_brain_conversation&.state.in?([nil, 'bot'])

    last_public = messages.reverse.find { |message| message.notifiable? }
    last_public&.incoming? || false
  end

  def pending_review(conversation)
    state = conversation.ai_brain_conversation
    return nil unless state&.state == 'review' && state.review_id.present?

    status, reviews = client.get('reviews/pending')
    return nil unless status == 200 && reviews.is_a?(Array)

    reviews.find { |review| review['id'] == state.review_id }
  rescue AiBrain::Client::UnavailableError
    nil
  end

  def message_payload(message)
    {
      id: message.id,
      content: message.content,
      role: message_role(message),
      private: message.private?,
      status: message.status,
      senderName: message.sender.try(:name),
      error: message.content_attributes&.dig('external_error'),
      createdAt: message.created_at.to_i
    }
  end

  def message_role(message)
    return 'activity' if message.activity?
    return 'client' if message.incoming?
    return 'note' if message.private?
    return 'bot' if message.sender_type == 'AgentBot'
    return 'secretary' if message.sender_type == 'User'

    'system'
  end
end
