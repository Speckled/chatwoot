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

  it 'flags the contact a number already has instead of creating a second one' do
    contact = create(:contact, account: account, phone_number: '+5511977776666', name: 'Paciente Carla')

    post "#{base}/staff_contacts", headers: headers, params: { phoneNumber: '+5511977776666', name: 'Carla' }, as: :json

    expect(response.parsed_body['contactId']).to eq(contact.id)
    expect(account.contacts.where(phone_number: '+5511977776666').count).to eq(1)
    expect(Conversation.ai_brain_staff_contact?(contact.reload, inbox.id)).to be(true)
  end

  describe 'removing the staff flag' do
    it "empties the flag of the number's contact and keeps the contact" do
      contact = create(:contact, account: account, phone_number: '+5511977776666',
                                 additional_attributes: { 'city' => 'Campinas', AiBrainStaffConversation::STAFF_INBOXES_KEY => [inbox.id] })

      delete "#{base}/staff_contacts", headers: headers, params: { phoneNumber: '+55 11 97777-6666' }, as: :json

      expect(response).to have_http_status(:no_content)
      contact.reload
      expect(contact.additional_attributes[AiBrainStaffConversation::STAFF_INBOXES_KEY]).to eq([])
      expect(contact.additional_attributes['city']).to eq('Campinas')
      expect(Conversation.ai_brain_staff_contact?(contact, inbox.id)).to be(false)
    end

    it 'does nothing for an unknown number' do
      other = create(:contact, account: account, phone_number: '+5511900001111',
                               additional_attributes: { AiBrainStaffConversation::STAFF_INBOXES_KEY => [inbox.id] })

      expect do
        delete "#{base}/staff_contacts", headers: headers, params: { phoneNumber: '+5511977776666' }, as: :json
      end.not_to change(Contact, :count)

      expect(response).to have_http_status(:no_content)
      expect(Conversation.ai_brain_staff_contact?(other.reload, inbox.id)).to be(true)
    end
  end

  describe 'looking up the contact of a number' do
    let!(:contact) { create(:contact, account: account, phone_number: '+5511977776666', name: 'Joana Lima') }

    it 'names the contact and reports patient conversations in an AI Brain inbox' do
      create(:conversation, account: account, inbox: inbox, contact: contact)

      get "#{base}/contacts/by_phone", headers: headers, params: { phoneNumber: '+5511977776666' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('contactId' => contact.id, 'name' => 'Joana Lima', 'patientConversations' => true)
    end

    it 'does not count staff conversations or inboxes the AI Brain does not serve' do
      other_inbox = create(:inbox, account: account)
      create(:conversation, account: account, inbox: other_inbox, contact: contact)
      create(:conversation, account: account, inbox: inbox, contact: contact,
                            additional_attributes: { AiBrainStaffConversation::AUDIENCE_KEY => AiBrainStaffConversation::STAFF_AUDIENCE })

      get "#{base}/contacts/by_phone", headers: headers, params: { phoneNumber: '+5511977776666' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['patientConversations']).to be(false)
    end

    it 'answers not found for a number without a contact' do
      get "#{base}/contacts/by_phone", headers: headers, params: { phoneNumber: '+5511900001111' }

      expect(response).to have_http_status(:not_found)
    end
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
