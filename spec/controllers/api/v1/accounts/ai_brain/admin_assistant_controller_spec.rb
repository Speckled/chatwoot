# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Brain admin assistant', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:client) { instance_double(AiBrain::Client) }
  let(:url) { "/api/v1/accounts/#{account.id}/ai_brain/admin_assistant" }

  before { allow(AiBrain::Client).to receive(:new).and_return(client) }

  it 'sends the message as the current user from the dashboard' do
    allow(client).to receive(:post).and_return([200, { 'textToSend' => 'Pronto.', 'cards' => [] }])

    post url, headers: admin.create_new_auth_token, params: { text: 'Quero adicionar uma caixa de entrada' }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['textToSend']).to eq('Pronto.')
    expected = { ownerUserId: admin.id, phoneNumber: "dashboard-user-#{admin.id}", messageType: 'text', channel: 'dashboard' }
    expect(client).to have_received(:post).with('owner/messages', hash_including(expected))
  end

  it 'shares the WhatsApp number as the turn key for an owner on the private channel' do
    AiBrainOwner.create!(account: account, user: admin, phone_number: '+5511966665555')
    allow(client).to receive(:post).and_return([200, { 'textToSend' => 'Ok' }])

    post url, headers: admin.create_new_auth_token, params: { text: 'Oi' }, as: :json

    expect(client).to have_received(:post).with('owner/messages', hash_including(phoneNumber: '+5511966665555'))
  end

  it 'reads the shared history' do
    allow(client).to receive(:get).and_return([200, [{ 'role' => 'user', 'text' => 'Oi' }]])

    get url, headers: admin.create_new_auth_token

    expect(response.parsed_body.pluck('text')).to eq(['Oi'])
    expect(client).to have_received(:get).with("owner/#{admin.id}/messages", {})
  end
end
