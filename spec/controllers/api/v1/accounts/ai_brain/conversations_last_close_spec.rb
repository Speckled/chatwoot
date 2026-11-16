# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Brain conversation: how its last session ended', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator, name: 'Ana Recepção') }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, status: :resolved) }
  let(:client) { instance_double(AiBrain::Client) }
  let(:url) { "/api/v1/accounts/#{account.id}/ai_brain/conversations/#{conversation.display_id}" }
  let(:close) do
    { 'sessionId' => SecureRandom.uuid, 'closedAt' => '2026-11-16T20:00:00Z', 'closedBy' => 'Person', 'closeReason' => 'Other',
      'closeNote' => 'Resolvido por telefone', 'closedByChatwootUserId' => admin.id }
  end

  before do
    allow(AiBrain::Client).to receive(:new).and_return(client)
    allow(client).to receive(:get).with("conversations/#{conversation.id}/staff-questions").and_return([200, []])
    allow(client).to receive(:get).with("conversations/#{conversation.id}/session/last-closed").and_return([200, close])
  end

  it 'shows an administrator who closed a resolved conversation, why, and the note' do
    get url, headers: admin.create_new_auth_token

    expect(response.parsed_body['lastClose']).to eq('closedBy' => 'Person', 'closeReason' => 'Other', 'closeNote' => 'Resolvido por telefone',
                                                    'closedAt' => '2026-11-16T20:00:00Z', 'closedByName' => 'Ana Recepção')
  end

  it 'does not ask for it while the conversation is open' do
    conversation.update!(status: :open)

    get url, headers: admin.create_new_auth_token

    expect(response.parsed_body['lastClose']).to be_nil
    expect(client).not_to have_received(:get).with("conversations/#{conversation.id}/session/last-closed")
  end

  it 'is not shown to agents' do
    get url, headers: agent.create_new_auth_token

    expect(response).to have_http_status(:unauthorized)
  end
end
