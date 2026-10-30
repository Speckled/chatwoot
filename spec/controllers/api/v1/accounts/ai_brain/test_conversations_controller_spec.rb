# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Brain Test Conversations API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  let(:test_channel) do
    Channel::Whatsapp.create!(
      account: account,
      phone_number: '+5511999990000',
      provider: 'test',
      provider_config: { 'source' => 'ai_brain_test' }
    )
  end
  let(:test_inbox) do
    inbox = create(:inbox, account: account, channel: test_channel)
    AiBrainInbox.create!(account: account, inbox: inbox, active: true)
    inbox
  end

  describe 'POST /api/v1/accounts/{account.id}/ai_brain/inboxes' do
    let(:url) { "/api/v1/accounts/#{account.id}/ai_brain/inboxes" }

    it 'creates a test WhatsApp inbox and activates AI Brain routing for an administrator' do
      post url,
           headers: admin.create_new_auth_token,
           params: { name: 'Clinica Teste', phone_number: '+5511988880000' },
           as: :json

      expect(response).to have_http_status(:created)
      data = response.parsed_body
      expect(data['name']).to eq('Clinica Teste')
      expect(data['provider']).to eq('test')
      expect(data['phoneNumber']).to eq('+5511988880000')
      expect(data['aiBrainInbox']['active']).to be(true)

      inbox = Inbox.find(data['id'])
      expect(inbox.channel).to be_a(Channel::Whatsapp)
      expect(inbox.channel.test_provider?).to be(true)
      expect(inbox.ai_brain_active?).to be(true)
    end

    it 'rejects agents' do
      post url,
           headers: agent.create_new_auth_token,
           params: { name: 'Clinica Teste', phone_number: '+5511988880000' },
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/ai_brain/test_conversations' do
    let(:url) { "/api/v1/accounts/#{account.id}/ai_brain/test_conversations" }

    it 'lists conversations with summary and last message' do
      contact = create(:contact, account: account, phone_number: '+5511933334444', name: 'Lucas')
      contact_inbox = ContactInboxBuilder.new(contact: contact, inbox: test_inbox).perform
      conv = create(:conversation, account: account, inbox: test_inbox, contact: contact, contact_inbox: contact_inbox)
      create(:message, account: account, inbox: test_inbox, conversation: conv, message_type: :incoming, content: 'Ola!', sender: contact)

      get url, headers: admin.create_new_auth_token, params: { inbox_id: test_inbox.id }, as: :json

      expect(response).to have_http_status(:ok)
      data = response.parsed_body
      expect(data.size).to eq(1)
      expect(data.first['contact']['name']).to eq('Lucas')
      expect(data.first['lastMessage']['content']).to eq('Ola!')
      expect(data.first['aiBrain']['aiEnabled']).to be(true)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/ai_brain/test_conversations/contacts' do
    let(:url) { "/api/v1/accounts/#{account.id}/ai_brain/test_conversations/contacts" }

    it 'returns contacts with phone numbers' do
      contact_with_phone = create(:contact, account: account, phone_number: '+5511911112222', name: 'Ana Silva')
      create(:contact, account: account, phone_number: nil, name: 'Sem Telefone')

      get url, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      data = response.parsed_body
      expect(data.pluck('id')).to include(contact_with_phone.id)
      expect(data.pluck('name')).not_to include('Sem Telefone')
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/ai_brain/test_conversations' do
    let(:url) { "/api/v1/accounts/#{account.id}/ai_brain/test_conversations" }

    it 'starts a conversation with a new phone number' do
      post url,
           headers: admin.create_new_auth_token,
           params: { inbox_id: test_inbox.id, phone_number: '+5511977776666', contact_name: 'Carlos Santos' },
           as: :json

      expect(response).to have_http_status(:created)
      data = response.parsed_body
      expect(data['contact']['name']).to eq('Carlos Santos')
      expect(data['contact']['phoneNumber']).to eq('+5511977776666')
      expect(data['status']).to eq('pending')
      expect(data['aiBrain']['aiEnabled']).to be(true)
    end

    it 'forces a new conversation even if upstream session close fails' do
      contact = create(:contact, account: account, phone_number: '+5511977776666', name: 'Carlos Santos')
      contact_inbox = ContactInboxBuilder.new(contact: contact, inbox: test_inbox).perform
      old_conv = create(:conversation, account: account, inbox: test_inbox, contact: contact, contact_inbox: contact_inbox)
      AiBrainConversation.create!(account: account, conversation: old_conv, session_id: 'sess-123', state: 'bot')

      allow_any_instance_of(AiBrain::Client).to receive(:post).and_raise(AiBrain::Client::UnavailableError, 'Service Unavailable')

      post url,
           headers: admin.create_new_auth_token,
           params: { inbox_id: test_inbox.id, phone_number: '+5511977776666', force_new: true },
           as: :json

      expect(response).to have_http_status(:created)
      expect(old_conv.reload.status).to eq('resolved')
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/ai_brain/test_conversations/{id}/messages' do
    let(:contact) { create(:contact, account: account, phone_number: '+5511955554444') }
    let(:contact_inbox) { ContactInboxBuilder.new(contact: contact, inbox: test_inbox).perform }
    let(:conversation) do
      conv = create(:conversation, account: account, inbox: test_inbox, contact: contact, contact_inbox: contact_inbox)
      conv.pending!
      conv
    end
    let(:url) { "/api/v1/accounts/#{account.id}/ai_brain/test_conversations/#{conversation.display_id}/messages" }

    it 'creates an incoming message when sent as client' do
      post url,
           headers: admin.create_new_auth_token,
           params: { content: 'Gostaria de agendar um horario', sender_role: 'client' },
           as: :json

      expect(response).to have_http_status(:created)
      msg = conversation.messages.last
      expect(msg.content).to eq('Gostaria de agendar um horario')
      expect(msg.message_type).to eq('incoming')
      expect(msg.sender).to eq(contact)
      expect(msg.source_id).to start_with('wamid.test.')
    end

    it 'creates an outgoing message when sent as secretary and preserves AI state' do
      post url,
           headers: admin.create_new_auth_token,
           params: { content: 'Bom dia, posso ajudar?', sender_role: 'secretary' },
           as: :json

      expect(response).to have_http_status(:created)
      msg = conversation.messages.last
      expect(msg.content).to eq('Bom dia, posso ajudar?')
      expect(msg.message_type).to eq('outgoing')
      expect(msg.sender).to eq(admin)
      expect(conversation.reload.ai_brain_conversation&.state).to be_in([nil, 'bot'])
    end

    it 'rejects empty messages' do
      post url,
           headers: admin.create_new_auth_token,
           params: { content: '   ', sender_role: 'client' },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
