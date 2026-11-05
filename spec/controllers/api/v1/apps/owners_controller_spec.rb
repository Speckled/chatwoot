# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Brain owner user changes', type: :request do
  let(:account) { create(:account) }
  let(:owner_user) { create(:user, account: account, role: :administrator) }
  let(:doctor) { create(:user, account: account, role: :agent, name: 'Ana') }
  let(:doctors) { create(:team, account: account, name: 'medicos') }
  let(:reception) { create(:team, account: account, name: 'recepcao') }
  let(:base) { "/api/v1/apps/chatwoot-main/owners/#{owner_user.id}/users" }
  let(:headers) { { 'X-Api-Key' => 'test-key' } }

  around { |example| with_modified_env(AI_BRAIN_API_KEY: 'test-key') { example.run } }

  before { AiBrainOwner.create!(account: account, user: owner_user, phone_number: '+5551995684103') }

  it 'changes the name, WhatsApp number, teams and role' do
    reception.add_members([doctor.id])

    patch "#{base}/#{doctor.id}",
          headers: headers,
          params: { displayName: 'Dra. Ana', whatsAppNumber: '+55 11 98888-7777', addTeamIds: [doctors.id], removeTeamIds: [reception.id],
                    role: 'administrator' },
          as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('userId' => doctor.id, 'displayName' => 'Dra. Ana', 'whatsAppNumber' => '+5511988887777',
                                            'teamIds' => [doctors.id], 'role' => 'administrator')
  end

  it 'refuses an unknown team, a bad number, and a change to the owner role' do
    patch "#{base}/#{doctor.id}", headers: headers, params: { addTeamIds: [0] }, as: :json
    expect(response.parsed_body['error']).to eq('A team does not exist in this account')

    patch "#{base}/#{doctor.id}", headers: headers, params: { whatsAppNumber: '123' }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    patch "#{base}/#{owner_user.id}", headers: headers, params: { role: 'agent' }, as: :json
    expect(response.parsed_body['error']).to eq('The owner cannot change their own role')
  end

  it 'removes someone from the account, but never the owner' do
    delete "#{base}/#{doctor.id}", headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(account.account_users.exists?(user_id: doctor.id)).to be(false)

    delete "#{base}/#{owner_user.id}", headers: headers, as: :json
    expect(response.parsed_body['error']).to eq('The owner cannot remove themself')
  end

  it 'refuses users of other accounts and owners who are no longer administrators' do
    outsider = create(:user, account: create(:account))

    patch "#{base}/#{outsider.id}", headers: headers, params: { displayName: 'X' }, as: :json
    expect(response.parsed_body['error']).to eq('User not found')

    owner_user.account_users.find_by(account: account).update!(role: :agent)
    delete "#{base}/#{doctor.id}", headers: headers, as: :json
    expect(response).to have_http_status(:not_found)
  end

  describe 'messages to the owner' do
    let(:url) { "/api/v1/apps/chatwoot-main/owners/#{owner_user.id}/messages" }
    let(:provider) { instance_double(Whatsapp::Providers::WhatsappTestService, send_text: 'wamid.sent') }
    let(:first_channel) do
      Channel::Whatsapp.create!(account: account, phone_number: '+5511999990001', provider: 'test', provider_config: { 'source' => 'ai_brain_test' })
    end
    let(:second_channel) do
      Channel::Whatsapp.create!(account: account, phone_number: '+5511999990002', provider: 'test', provider_config: { 'source' => 'ai_brain_test' })
    end
    # Created before the provider is stubbed: creating a channel validates its provider config.
    let!(:first_inbox) { create(:inbox, account: account, channel: first_channel) }
    let!(:second_inbox) { create(:inbox, account: account, channel: second_channel) }

    before do
      allow(Whatsapp::Providers::WhatsappTestService).to receive(:new).and_return(provider)
      AiBrainInbox.create!(account: account, inbox: first_inbox, active: true)
      AiBrainInbox.create!(account: account, inbox: second_inbox, active: true)
    end

    it 'sends the text to the owner through the inbox they wrote to' do
      post url, headers: headers, params: { text: '✅ Google Drive conectado.', inboxId: second_inbox.id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('inboxId' => second_inbox.id)
      expect(provider).to have_received(:send_text).with('5551995684103', '✅ Google Drive conectado.')
    end

    it 'uses the first AI Brain WhatsApp inbox when the given one is not one' do
      AiBrainInbox.find_by(inbox: second_inbox).update!(active: false)

      post url, headers: headers, params: { text: 'Oi', inboxId: second_inbox.id }, as: :json

      expect(response.parsed_body).to eq('inboxId' => first_inbox.id)
    end

    it 'refuses a missing text, an account without an AI Brain WhatsApp inbox, and a message WhatsApp did not accept' do
      post url, headers: headers, params: { text: ' ' }, as: :json
      expect(response.parsed_body['error']).to eq('text is required')

      allow(provider).to receive(:send_text).and_return(nil)
      post url, headers: headers, params: { text: 'Oi' }, as: :json
      expect(response).to have_http_status(:bad_gateway)

      AiBrainInbox.where(account: account).find_each { |ai_inbox| ai_inbox.update!(active: false) }
      post url, headers: headers, params: { text: 'Oi' }, as: :json
      expect(response.parsed_body['error']).to eq('The account has no AI Brain WhatsApp inbox')
    end
  end
end
