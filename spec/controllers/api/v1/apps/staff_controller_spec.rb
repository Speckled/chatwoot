# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Brain staff API', type: :request do
  let(:account) { create(:account) }
  let(:channel) do
    Channel::Whatsapp.create!(account: account, phone_number: '+5511999990000', provider: 'test', provider_config: { 'source' => 'ai_brain_test' })
  end
  let!(:inbox) do
    inbox = create(:inbox, account: account, channel: channel)
    AiBrainInbox.create!(account: account, inbox: inbox, active: true)
    inbox
  end
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/apps/chatwoot-main/accounts/#{account.id}" }
  let(:headers) { { 'X-Api-Key' => 'test-key' } }

  around { |example| with_modified_env(AI_BRAIN_API_KEY: 'test-key') { example.run } }

  it 'flags a new staff contact in every AI Brain WhatsApp inbox, so their conversations are staff-only' do
    post "#{base}/staff_contacts", headers: headers, params: { phoneNumber: '+55 11 97777-6666', name: 'Carla' }, as: :json

    expect(response).to have_http_status(:ok)
    contact = account.contacts.find(response.parsed_body['contactId'])
    expect(contact.phone_number).to eq('+5511977776666')
    expect(Conversation.ai_brain_staff_contact?(contact, inbox.id)).to be(true)
  end

  it 'refuses a number without its country code' do
    post "#{base}/staff_contacts", headers: headers, params: { phoneNumber: '1234', name: 'Carla' }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'registers and removes an administrator on the private channel' do
    put "#{base}/assistants/#{admin.id}", headers: headers, params: { phoneNumber: '+5511966665555' }, as: :json

    expect(response).to have_http_status(:ok)
    expect(account.ai_brain_owners.find_by(user: admin).phone_number).to eq('+5511966665555')

    delete "#{base}/assistants/#{admin.id}", headers: headers

    expect(response).to have_http_status(:no_content)
    expect(account.ai_brain_owners.where(user: admin)).to be_empty
  end

  it 'keeps the private channel for administrators' do
    put "#{base}/assistants/#{agent.id}", headers: headers, params: { phoneNumber: '+5511966665555' }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
