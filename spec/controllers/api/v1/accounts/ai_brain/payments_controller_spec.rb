# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Brain payments', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:client) { instance_double(AiBrain::Client) }
  let(:conversation) { create(:conversation, account: account) }

  before { allow(AiBrain::Client).to receive(:new).and_return(client) }

  it 'lists the payments with the display id of each conversation' do
    allow(client).to receive(:get).and_return([200, [{ 'id' => 'p1', 'chatwootConversationId' => conversation.id },
                                                     { 'id' => 'p2', 'chatwootConversationId' => nil }]])

    get "/api/v1/accounts/#{account.id}/ai_brain/payments", headers: admin.create_new_auth_token, params: { status: 'approved' }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.pluck('conversationDisplayId')).to eq([conversation.display_id, nil])
    expect(client).to have_received(:get).with('payments', { 'status' => 'approved' })
  end

  it 'refunds a payment' do
    allow(client).to receive(:post).and_return([200, { 'status' => 'refunded' }])
    id = SecureRandom.uuid

    post "/api/v1/accounts/#{account.id}/ai_brain/payments/#{id}/refund", headers: admin.create_new_auth_token

    expect(response).to have_http_status(:ok)
    expect(client).to have_received(:post).with("payments/#{id}/refund")
  end

  it 'is for administrators only' do
    get "/api/v1/accounts/#{account.id}/ai_brain/payments", headers: agent.create_new_auth_token

    expect(response).to have_http_status(:unauthorized)
  end
end
