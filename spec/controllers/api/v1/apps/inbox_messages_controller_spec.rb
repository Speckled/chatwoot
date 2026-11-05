# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Brain inbox messages API', type: :request do
  let(:account) { create(:account) }
  let(:channel) do
    Channel::Whatsapp.create!(account: account, phone_number: '+5511999990000', provider: 'test', provider_config: { 'source' => 'ai_brain_test' })
  end
  let(:inbox) do
    inbox = create(:inbox, account: account, channel: channel)
    AiBrainInbox.create!(account: account, inbox: inbox, active: true)
    inbox
  end
  let(:url) { "/api/v1/apps/chatwoot-main/inboxes/#{inbox.id}/messages" }
  let(:headers) { { 'X-Api-Key' => 'test-key' } }
  let(:outgoing_id) { SecureRandom.uuid }
  let(:body) do
    { outgoingId: outgoing_id, to: { phoneNumber: '+55 11 98888-7777', name: 'Maria Silva' },
      text: 'Olá Maria, sua consulta é amanhã às 14:00.', audience: 'client', aiReplies: true }
  end

  around { |example| with_modified_env(AI_BRAIN_API_KEY: 'test-key') { example.run } }

  it 'creates the contact and a pending conversation for the AI, and posts the message as the AI Brain bot' do
    post url, headers: headers, params: body, as: :json

    expect(response).to have_http_status(:ok)
    data = response.parsed_body
    message = Message.find(data['chatwootMessageId'])
    conversation = message.conversation
    expect(conversation.contact).to have_attributes(phone_number: '+5511988887777', name: 'Maria Silva')
    expect(conversation).to be_pending
    expect(conversation.ai_brain_conversation).to be_nil
    expect(message).to have_attributes(message_type: 'outgoing', content: body[:text], sender: AiBrain::BotSender.for(account))
    expect(message.additional_attributes['ai_brain_outgoing_id']).to eq(outgoing_id)
    expect(data).to include('chatwootConversationId' => conversation.id, 'chatwootConversationDisplayId' => conversation.display_id,
                            'contactId' => conversation.contact_id, 'duplicate' => false)
  end

  it 'posts a retried message only once' do
    2.times { post url, headers: headers, params: body, as: :json }

    expect(response.parsed_body['duplicate']).to be(true)
    expect(Message.where("additional_attributes->>'ai_brain_outgoing_id' = ?", outgoing_id).count).to eq(1)
  end

  it "uses the contact's own thread and leaves a conversation under way with whoever handles it" do
    contact = create(:contact, account: account, phone_number: '+5511988887777')
    contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox, source_id: '551188887777')
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox)
    AiBrainConversation.create!(account: account, conversation: conversation, state: 'human')
    conversation.open!

    post url, headers: headers, params: body, as: :json

    expect(response.parsed_body['chatwootConversationId']).to eq(conversation.id)
    expect(conversation.reload).to be_open
    expect(conversation.ai_brain_conversation.state).to eq('human')
  end

  it 'hands a resolved conversation back to the AI when the message asks for its replies' do
    contact = create(:contact, account: account, phone_number: '+5511988887777')
    contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5511988887777')
    inbox.update!(lock_to_single_conversation: true)
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox)
    AiBrainConversation.create!(account: account, conversation: conversation, state: 'human')
    conversation.resolved!

    post url, headers: headers, params: body, as: :json

    expect(response.parsed_body['chatwootConversationId']).to eq(conversation.id)
    expect(conversation.reload).to be_pending
    expect(conversation.ai_brain_conversation.state).to eq('bot')
  end

  it 'opens the conversation for receptionists when the AI is not to answer' do
    post url, headers: headers, params: body.merge(aiReplies: false), as: :json

    conversation = Conversation.find(response.parsed_body['chatwootConversationId'])
    expect(conversation).to be_open
    expect(conversation.ai_brain_conversation.state).to eq('human')
  end

  it 'sends the WhatsApp template with its body parameters in order' do
    template = { name: 'lembrete_consulta', language: 'pt_BR', category: 'UTILITY', bodyParameters: %w[Maria 06/11] }

    post url, headers: headers, params: body.merge(template: template), as: :json

    message = Message.find(response.parsed_body['chatwootMessageId'])
    expect(message.additional_attributes['template_params']).to eq(
      'name' => 'lembrete_consulta', 'language' => 'pt_BR', 'category' => 'UTILITY',
      'processed_params' => { 'body' => { '1' => 'Maria', '2' => '06/11' } }
    )
  end

  it 'keeps a message to staff for administrators, with the AI kept out' do
    post url, headers: headers, params: body.merge(audience: 'staff'), as: :json

    conversation = Conversation.find(response.parsed_body['chatwootConversationId'])
    expect(conversation).to be_ai_brain_staff
    expect(conversation).to be_pending
    expect(conversation.ai_brain_conversation.state).to eq('human')
    expect(Conversation.ai_brain_staff_contact?(conversation.contact, inbox.id)).to be(true)
  end

  it 'keeps a new staff conversation pending on an inbox the AI does not serve' do
    inbox.ai_brain_inbox.update!(active: false)

    post url, headers: headers, params: body.merge(audience: 'staff'), as: :json

    conversation = Conversation.find(response.parsed_body['chatwootConversationId'])
    expect(conversation).to be_ai_brain_staff
    expect(conversation).to be_pending
  end

  it 'refuses what cannot be sent' do
    widget_inbox = create(:inbox, account: account)
    instagram_inbox = create(:inbox, account: account, channel: create(:channel_instagram, account: account))

    post "/api/v1/apps/chatwoot-main/inboxes/#{widget_inbox.id}/messages", headers: headers, params: body, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    post "/api/v1/apps/chatwoot-main/inboxes/#{instagram_inbox.id}/messages", headers: headers, params: body, as: :json
    expect(response.parsed_body['error']).to eq('Instagram can only message someone who has written to this inbox')

    post "/api/v1/apps/chatwoot-main/inboxes/#{instagram_inbox.id}/messages",
         headers: headers, params: body.merge(template: { name: 'x', language: 'pt_BR' }), as: :json
    expect(response.parsed_body['error']).to eq('Templates are sent only through WhatsApp inboxes')

    post url, headers: headers, params: body.merge(to: { phoneNumber: '123' }), as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    post '/api/v1/apps/chatwoot-main/inboxes/0/messages', headers: headers, params: body, as: :json
    expect(response).to have_http_status(:not_found)

    post url, headers: { 'X-Api-Key' => 'wrong' }, params: body, as: :json
    expect(response).to have_http_status(:unauthorized)
  end
end
