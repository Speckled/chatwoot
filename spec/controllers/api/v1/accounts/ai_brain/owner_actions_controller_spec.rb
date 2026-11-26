# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Brain owner actions', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:client) { instance_double(AiBrain::Client) }
  let(:audit) { { 'changes' => [{ 'id' => 'a1', 'description' => 'Adicionar a FAQ', 'outcome' => 'confirmed' }], 'people' => [] } }
  let(:url) { "/api/v1/accounts/#{account.id}/ai_brain/owner_actions" }

  before { allow(AiBrain::Client).to receive(:new).and_return(client) }

  it 'passes the period, the person and the limit to the backend and renders its answer' do
    allow(client).to receive(:get).and_return([200, audit])
    person = SecureRandom.uuid
    period = { from: '2026-11-01T03:00:00Z', to: '2026-11-27T03:00:00Z' }

    get url, headers: admin.create_new_auth_token, params: period.merge(staff_user_id: person, limit: 200, other: 'x')

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(audit)
    expect(client).to have_received(:get)
      .with('owner-actions', { 'from' => period[:from], 'to' => period[:to], 'staffUserId' => person, 'limit' => '200' })
  end

  it 'leaves out the filters that are not chosen' do
    allow(client).to receive(:get).and_return([200, audit])

    get url, headers: admin.create_new_auth_token, params: { staff_user_id: '' }

    expect(client).to have_received(:get).with('owner-actions', {})
  end

  it 'is for administrators only' do
    allow(client).to receive(:get)

    get url, headers: agent.create_new_auth_token

    expect(response).to have_http_status(:unauthorized)
    expect(client).not_to have_received(:get)
  end
end
